import 'package:aaryapay/screens/Home/components/recent_card.dart';
import 'package:flutter/material.dart';
import 'package:aaryapay/screens/Home/components/favourites.dart';
import 'package:aaryapay/screens/Home/components/last_synchronized.dart';


class Midsection extends StatelessWidget {
  const Midsection({
    super.key,
    required this.size,
  });
  final Size size;
  

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Favourites(),
          const LastSynchronized(),
          RecentCard(size: size),
        ],
      ),
    );
  }
}
