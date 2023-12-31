import 'package:aaryapay/components/CustomTextField.dart';
import 'package:aaryapay/components/SnackBarService.dart';
import 'package:aaryapay/constants.dart';
import 'package:aaryapay/helper/utils.dart';
import 'package:aaryapay/screens/Login/bloc/forgot_bloc.dart';
import 'package:aaryapay/screens/Login/components/login_wrapper.dart';
import 'package:aaryapay/screens/Login/otp_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ResetPassword extends StatelessWidget {
  const ResetPassword({Key? key, this.userid}) : super(key: key);
  final String? userid;

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return BlocProvider(
      create: (context) => ForgotBloc(),
      child: BlocConsumer<ForgotBloc, ForgotState>(
        listener: (context, state) {
          if (state.status == ForgotStatus.error) {
            SnackBarService.stopSnackBar();
            SnackBarService.showSnackBar(
              content: state.errorText,
            );
          }
          if (state.matched) {
            Utils.mainAppNav.currentState!.push(
              PageRouteBuilder(
                pageBuilder: (context, animation1, animation2) => OTPScreen(
                  userid: userid,
                  password: state.passOne,
                ),
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              ),
            );
          }
        },
        builder: (context, state) {
          return LoginWrapper(
              forgotStatus: state.status,
              backButton: true,
              actionButtonLabel: "Submit",
              backButttonFunction: () => {Navigator.pop(context)},
              actionButtonFunction: () => {
                    context.read<ForgotBloc>().add(CheckMatching()),
                  },
              children: _midsection(context, size));
        },
      ),
    );
  }

  Widget _midsection(BuildContext context, Size size) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 300,
          child: Text(
            "Reset Password?",
            // overflow: TextOverflow.fade,
            style: Theme.of(context).textTheme.headlineMedium!.merge(
                  TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.primary),
                ),
          ),
        ),
        CustomTextField(
          onChanged: (value) => {
            context
                .read<ForgotBloc>()
                .add(ForgotPasswordOneChanged(pass: value))
          },
          prefixIcon: Icon(
            FontAwesomeIcons.lock,
            color: Theme.of(context).colorScheme.primary,
          ),
          width: size.width,
          suffixIcon: const Align(
            heightFactor: 1,
            widthFactor: 3,
            child: Icon(
              FontAwesomeIcons.eyeSlash,
              size: 20,
            ),
          ),

          // height: 1,
          // error: "Incorrect Password",
          isPassword: true,
          padding: const EdgeInsets.only(top: 20),
          placeHolder: "Password",
        ),
        CustomTextField(
          onChanged: (value) => {
            context
                .read<ForgotBloc>()
                .add(ForgotPasswordTwoChanged(pass: value))
          },
          prefixIcon: Icon(
            FontAwesomeIcons.lock,
            color: Theme.of(context).colorScheme.primary,
          ),
          width: size.width,
          suffixIcon: const Align(
            heightFactor: 1,
            widthFactor: 3,
            child: Icon(
              FontAwesomeIcons.eyeSlash,
              size: 20,
            ),
          ),

          // height: 1,
          // error: "Incorrect Password",
          isPassword: true,
          padding: const EdgeInsets.only(top: 20),
          placeHolder: "Password",
        ),
      ],
    );
  }
}
