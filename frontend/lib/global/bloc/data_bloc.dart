import 'dart:async';
import 'dart:convert';
import 'package:aaryapay/helper/utils.dart';
import 'package:cryptography/cryptography.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:aaryapay/global/caching/profile.dart';
import 'package:aaryapay/global/caching/transaction.dart';
import 'package:aaryapay/global/caching/favorite.dart';
import 'package:libaaryapay/transaction/bkvc.dart';
import 'package:libaaryapay/transaction/utils.dart';
import 'package:aaryapay/constants.dart';
import 'package:libaaryapay/transaction/tvc.dart';
import 'package:libaaryapay/transaction/tam.dart';

part 'data_state.dart';
part 'data_event.dart';

class DataBloc extends Bloc<DataEvent, DataState> {
  static const storage = FlutterSecureStorage();
  final httpclient = http.Client();

  DataBloc() : super(const DataState()) {
    on<LoadDataEvent>(_onLoadData);
    on<RequestSyncEvent>(_onRequestSync);
    on<SubmitTVCEvent>(_onSubmitTVC);
    on<SubmitTAMEvent>(_onSubmitTAM);
    on<UserAuthenticatedEvent>(_onUserAuthenticated);
    on<UpdateServerKeyEvent>(_onUpdateServerKey);
    on<CheckInternet>(_onCheckInternet);
    on<TimerUp>(_onTimerUp);
    add(LoadDataEvent());
  }

  Future<void> _onTimerUp(TimerUp event, Emitter<DataState> emit) async {
    if (event.ticking) {
      if (state.tamStatus == TAMStatus.initiated) {
        emit(state.copyWith(goToScreen: GoToScreen.offlineTrans));
      }
      if (state.tamStatus == TAMStatus.completed) {
        emit(state.copyWith(goToScreen: GoToScreen.onlineTrans));
      }
    } else {
      if (state.tamStatus == TAMStatus.initiated) {
        emit(state.copyWith(goToScreen: GoToScreen.recOfflineTrans));
      }
      if (state.tamStatus == TAMStatus.completed) {
        emit(state.copyWith(goToScreen: GoToScreen.onlineTrans));
      }
    }
    emit(state.copyWith(
        tamStatus: TAMStatus.other, goToScreen: GoToScreen.unknown));
    return;
  }

  Future<void> _onCheckInternet(
      CheckInternet event, Emitter<DataState> emit) async {
    bool isOnline = await checkInternetConnectivity();

    if (state.isOnline != isOnline) {
      emit(state.copyWith(isOnline: isOnline));

      if (state.isOnline) {
        add(RequestSyncEvent());
      }
    }
    return;
  }

  Future<void> _onLoadData(
    LoadDataEvent event,
    Emitter<DataState> emit,
  ) async {
    Timer.periodic(Duration(seconds: 1), (Timer t) {
      add(CheckInternet());
    });
    var temp = await DataState.fromStorage(storage);
    emit(temp);
    add(RequestSyncEvent());
  }

  Future<void> _onRequestSync(
    RequestSyncEvent event,
    Emitter<DataState> emit,
  ) async {
    var url = Uri.parse('$backendBase/sync');

    var transactionToSubmit =
        await state.transactions.getUnsubmittedTransactions();

    final headers = {
      "Content-Type": "application/x-www-form-urlencoded",
      "Cookie": "session=${state.sessionToken}",
    };

    http.Response response;
    if (transactionToSubmit.isEmpty) {
      response = await httpclient.post(url, headers: headers);
    } else {
      var base64Trans = [];

      for (var i in transactionToSubmit) {
        base64Trans
            .add(base64Encode(i.authorizationMessage!.toBytes()).toString());
      }
      var body = {
        "transactions": "{\"data\" : ${jsonEncode(base64Trans)}}",
      };

      response = await httpclient.post(url, headers: headers, body: body);
    }

    if (response.statusCode != 202) {
      return;
    }

    emit(state.copyWith(tamStatus: TAMStatus.completed));

    var responseData = jsonDecode(response.body);

    if (responseData.containsKey('success')) {
      List<Favorite> favorites = [];
      if (responseData['favorites'] != null) {
        favorites = responseData['favorites']
            .map<Favorite>(
              (favorite) => Favorite.fromJson(favorite),
            )
            .toList();
      }
      print(responseData['bkvc']);
      BalanceKeyVerificationCertificate bkvc =
          BalanceKeyVerificationCertificate.fromBase64(responseData['bkvc']);

      Profile profile = Profile.fromJson(responseData['profile']);

      Transactions transactions = Transactions(transactions: []);
      Transaction latestTransaction = Transaction(credit: false);

      if (responseData['transactions'] != null) {
        transactions = Transactions.fromJson(
          responseData['transactions'],
          bkvc.userID,
        );

        latestTransaction = await transactions.getLatest();
      }

      DataState newState = DataState(
        profile: profile,
        transactions: transactions,
        favorites: favorites,
        bkvc: bkvc,
        primary: state.primary,
        serverPublicKey: state.serverPublicKey,
        sessionToken: state.sessionToken,
        isLoaded: true,
      );

      newState.save(storage);

      emit(
        state.copyWith(
          profile: profile,
          transactions: transactions,
          favorites: favorites,
          bkvc: bkvc,
          primary: state.primary,
          serverPublicKey: state.serverPublicKey,
          sessionToken: state.sessionToken,
          isLoaded: true,
          latestTransaction: latestTransaction,
        ),
      );
    }
  }

  Future<void> _onSubmitTAM(
    SubmitTAMEvent event,
    Emitter<DataState> emit,
  ) async {
    print("Submit TAM");
    print(base64.encode(event.tam.toBytes()));
    emit(state.copyWith(tamStatus: TAMStatus.initiated));

    bool alreadyExists = await state.transactions
        .checkAlreadyExists(event.tam.timeStamp, event.tam.amount);
    Transactions newTransactions;
    var transaction = Transaction(
      authorizationMessage: event.tam,
      credit: event.tam.to == state.bkvc!.userID,
    );
    if (!alreadyExists) {
      newTransactions = Transactions(
        transactions: [...state.transactions.transactions, transaction],
      );
    } else {
      newTransactions = Transactions(
        transactions: [...state.transactions.transactions],
      );
    }
    DataState newState = state.copyWith(
        transactions: newTransactions, latestTransaction: transaction);

    newState.save(storage);
    emit(newState);
    add(RequestSyncEvent());

    Timer(Duration(seconds: 3), () => {add(TimerUp(event.ticking))});
  }

  Future<void> _onSubmitTVC(
    SubmitTVCEvent event,
    Emitter<DataState> emit,
  ) async {
    Transaction? transaction;
    var serverKey = keyPairFromBase64(serverKeyPair);

    var serverPublic = await serverKey.extractPublicKey();
    bool verified = await event.tvc.verify(serverPublic);

    if (event.tvc.bkvc.userID != state.bkvc!.userID) {
      throw Exception('TVC is not for this user!');
    }

    if (!verified) {
      throw Exception('TVC could not be verified!');
    }
    Transaction recentTransaction;
    var credit = event.tvc.from != state.bkvc!.userID;

    bool alreadyExists = await state.transactions
        .checkAlreadyExists(event.tvc.timeStamp, event.tvc.amount);

    Transactions newTransactions;
    if (alreadyExists) {
      newTransactions = Transactions(
        transactions: [...state.transactions.transactions],
      );

      var specificTransaction =
          newTransactions.transactions.firstWhere((element) {
        return element.generationTime == event.tvc.timeStamp &&
            element.amount == event.tvc.amount;
      });

      if (credit) {
        specificTransaction.receiverTvc = event.tvc;
      } else {
        specificTransaction.senderTvc = event.tvc;
      }

      recentTransaction = specificTransaction;
    } else {
      if (credit) {
        transaction = Transaction(
          receiverTvc: event.tvc,
          credit: credit,
        );
      } else {
        transaction = Transaction(
          senderTvc: event.tvc,
          credit: credit,
        );
      }

      newTransactions = Transactions(
        transactions: [...state.transactions.transactions, transaction],
      );
      recentTransaction = transaction;
    }

    BalanceKeyVerificationCertificate newBKVC;
    if (event.tvc.bkvc.timeStamp.isAfter(state.bkvc!.timeStamp)) {
      newBKVC = event.tvc.bkvc;
    } else {
      newBKVC = state.bkvc!;
    }

    DataState newState = state.copyWith(
      transactions: newTransactions,
      bkvc: newBKVC,
      goToScreen: GoToScreen.tvcSuccess,
      recentTransaction: recentTransaction,
    );

    newState.save(storage);
    emit(newState);
    emit(state.copyWith(
      goToScreen: GoToScreen.unknown,
    ));
  }

  Future<void> _onUpdateServerKey(
    UpdateServerKeyEvent event,
    Emitter<DataState> emit,
  ) async {
    var url = Uri.parse('$backendBase/keys/server_keys');

    final response = await httpclient.get(url);

    if (response.statusCode != 200) {
      throw Exception('Server key could not be retrieved!');
    }

    if (response.body.isNotEmpty) {
      var resposeData = jsonDecode(response.body);

      var publicKeyBase64 = resposeData['pubkey'];

      if (publicKeyBase64 == null) {
        throw Exception('Server key could not be retrieved!');
      }

      var serverPublicKeyDecoded = publicKeyFromBase64(publicKeyBase64);

      bool verified = await Ed25519().verify(
        utf8.encode(resposeData['message']),
        signature: Signature(
          base64Decode(resposeData['signature']),
          publicKey: serverPublicKeyDecoded,
        ),
      );

      if (!verified) {
        throw Exception('Server key could not be verified!');
      }

      DataState newState =
          state.copyWith(serverPublicKey: serverPublicKeyDecoded);

      newState.save(storage);

      emit(newState);
    }
  }

  Future<void> _onUserAuthenticated(
    UserAuthenticatedEvent event,
    Emitter<DataState> emit,
  ) async {
    emit(state.copyWith(
      sessionToken: event.sessionToken,
      primary: event.isPrimary,
      isLoaded: false,
    ));
    add(RequestSyncEvent());
  }
}
