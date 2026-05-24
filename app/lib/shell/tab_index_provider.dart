import 'package:flutter_riverpod/flutter_riverpod.dart';

class TabIndex extends Notifier<int> {
  @override
  int build() => 0;

  void set(int value) => state = value;
}

final tabIndexProvider = NotifierProvider<TabIndex, int>(TabIndex.new);
