import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/riverpod.dart';
import 'package:sync_once/sync_once.dart';
import 'package:synchronized/synchronized.dart';

abstract class FutureStateNotifier<T> extends StateNotifier<AsyncValue<T>> {
  final lock = Lock();
  final once = SyncOnce();

  FutureStateNotifier() : super(const AsyncValue.loading());

  Future<void> initState();

  Future<void> initStateOnce() async {
    await once(initState);
  }

  Future<void> setState(Future<T> Function() future) async {
    lock.synchronized(() async {
      if (state != const AsyncValue.loading()) {
        state = const AsyncValue.loading();
      }
      state = await AsyncValue.guard(future);
    });
  }
}

extension WidgetRefX on WidgetRef {
  Future<T?> watchValue<T>(
      StateNotifierProvider<FutureStateNotifier<T>, AsyncValue<T>>
          provider) async {
    final notifier = read(provider.notifier);
    await notifier.initStateOnce();

    return watch(provider).data?.value;
  }

  AsyncValue<T> watchAsyncValue<T>(
      StateNotifierProvider<FutureStateNotifier<T>, AsyncValue<T>> provider) {
    final notifier = read(provider.notifier);
    notifier.initStateOnce();

    return watch(provider);
  }
}

extension ProviderRefBaseX on ProviderRefBase {
  Future<T?> watchValueByProviderRefBase<T>(
      StateNotifierProvider<FutureStateNotifier<T>, AsyncValue<T>>
          provider) async {
    final notifier = read(provider.notifier);
    await notifier.initStateOnce();

    return watch(provider).data?.value;
  }

  AsyncValue<T> watchAsyncValueByProviderRefBase<T>(
      StateNotifierProvider<FutureStateNotifier<T>, AsyncValue<T>> provider) {
    final notifier = read(provider.notifier);
    notifier.initStateOnce();

    return watch(provider);
  }
}
