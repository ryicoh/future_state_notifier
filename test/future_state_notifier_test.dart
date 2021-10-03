import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:future_state_notifier/future_state_notifier.dart';
import 'package:sync_once/sync_once.dart';
import 'package:test/test.dart';

import 'helper.dart';

class Counter extends StateNotifier<int?> {
  Counter() : super(null);

  Future<void> setCounter(int counter, {Duration? duration}) async {
    if (duration != null) {
      await Future.delayed(duration);
    }

    state = counter;
  }

  Future<void> slowIncrement({Duration? duration}) async {
    if (duration != null) {
      await Future.delayed(duration);
    }

    if (state == null) {
      state = 0;
    } else {
      state = state! + 1;
    }
  }
}

class FutureCounter extends FutureStateNotifier<int> {
  @override
  Future<void> initState() async {
    await setState(() async {
      return 123;
    });
  }

  Future<void> slowIncrement({Duration? duration}) async {
    final current = state.data;

    await setState(() async {
      if (duration != null) {
        await Future.delayed(duration);
      }

      if (current == null) {
        return 0;
      }

      return current.value + 1;
    });
  }
}

void main() {
  test("StateProvider + FutureProvider", () async {
    final provider = StateNotifierProvider<Counter, int?>((ref) => Counter());

    final once = SyncOnce();
    final futureProvider = FutureProvider((ref) async {
      await once(() async {
        await ref.read(provider.notifier).setCounter(123);
      });
      return ref.watch(provider);
    });

    final listener = Listener<AsyncValue<int?>>();

    final container = ProviderContainer();
    container.listen<AsyncValue<int?>>(futureProvider, (value) {
      listener(value);
    }, fireImmediately: true);

    verify(listener(AsyncValue.loading())).called(1);
    await Future.delayed(Duration(seconds: 1));
    verify(listener(AsyncValue.data(123))).called(1);
    verifyNoMoreInteractions(listener);

    container
        .read(provider.notifier)
        .slowIncrement(duration: Duration(seconds: 1));
    await Future.delayed(Duration(milliseconds: 100));

    // We want the state to be "Async.loading",
    // but in the case of "StateProvider + FutureProvider", it is impossible.
    verifyNever(listener(AsyncValue.loading()));

    await Future.delayed(Duration(seconds: 1));
    verify(listener(AsyncValue.loading())).called(1);
    verify(listener(AsyncValue.data(124))).called(1);
    verifyNoMoreInteractions(listener);
  });

  test("FutureStateNotifier", () async {
    final provider = StateNotifierProvider<FutureCounter, AsyncValue<int>>(
        (ref) => FutureCounter());
    final container = ProviderContainer();
    final listener = Listener<AsyncValue<int>>();

    container.listen<AsyncValue<int>>(Provider((ref) {
      final notifier = ref.read(provider.notifier);
      notifier.initStateOnce();

      return ref.watch(provider);
    }), (value) => listener(value), fireImmediately: true);

    verify(listener(AsyncValue.loading())).called(1);
    await Future.delayed(Duration(seconds: 1));
    verify(listener(AsyncValue.data(123))).called(1);
    verifyNoMoreInteractions(listener);

    container
        .read(provider.notifier)
        .slowIncrement(duration: Duration(seconds: 1));
    await Future.delayed(Duration(milliseconds: 100));

    // Called "AsyncValue.loading()" !!
    verify(listener(AsyncValue.loading())).called(1);

    await Future.delayed(Duration(seconds: 1));
    verify(listener(AsyncValue.data(124))).called(1);
    verifyNoMoreInteractions(listener);
  });
}
