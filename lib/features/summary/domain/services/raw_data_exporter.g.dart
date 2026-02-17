// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'raw_data_exporter.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(rawDataExporter)
final rawDataExporterProvider = RawDataExporterProvider._();

final class RawDataExporterProvider
    extends
        $FunctionalProvider<RawDataExporter, RawDataExporter, RawDataExporter>
    with $Provider<RawDataExporter> {
  RawDataExporterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rawDataExporterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rawDataExporterHash();

  @$internal
  @override
  $ProviderElement<RawDataExporter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RawDataExporter create(Ref ref) {
    return rawDataExporter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RawDataExporter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RawDataExporter>(value),
    );
  }
}

String _$rawDataExporterHash() => r'4ba50680e077fa0445bcaf27c4bd1d7fdc9c681f';
