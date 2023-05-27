import 'package:aaryapay/screens/Home/components/recent_card.dart';
import 'package:flutter/material.dart';
import 'package:aaryapay/screens/Home/components/favourites.dart';
import 'package:aaryapay/screens/Home/components/last_synchronized.dart';

Future<void> _refresh() async {}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: _refresh,
      child: GestureDetector(
        child: Container(
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(35),
              topRight: Radius.circular(35),
            ),
            color: Color(0xfff4f6f4),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: const [
                Favourites(),
                LastSynchronized(),
                RecentCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
