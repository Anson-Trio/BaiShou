// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'context_builder.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(contextBuilder)
final contextBuilderProvider = ContextBuilderProvider._();

final class ContextBuilderProvider
    extends $FunctionalProvider<ContextBuilder, ContextBuilder, ContextBuilder>
    with $Provider<ContextBuilder> {
  ContextBuilderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contextBuilderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contextBuilderHash();

  @$internal
  @override
  $ProviderElement<ContextBuilder> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ContextBuilder create(Ref ref) {
    return contextBuilder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ContextBuilder value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ContextBuilder>(value),
    );
  }
}

String _$contextBuilderHash() => r'af2c4e9877102824e52c8cbe89f57107543eb5ba';
