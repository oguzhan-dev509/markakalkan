import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:markakalkan/modules/marka_kalkan/dijital_pazar_izleme/services/monitoring_pdf_report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> runCase(String name, MonitoringPdfReportData report) async {
    final stopwatch = Stopwatch()..start();

    try {
      final Uint8List bytes = await MonitoringPdfReportService.build(report);

      stopwatch.stop();

      // ignore: avoid_print
      print(
        'PDF_TEST_OK | $name | '
        'bytes=${bytes.length} | '
        'ms=${stopwatch.elapsedMilliseconds}',
      );

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(500));
    } catch (error, stackTrace) {
      stopwatch.stop();

      // ignore: avoid_print
      print(
        'PDF_TEST_ERROR | $name | '
        'type=${error.runtimeType} | '
        'error=$error | '
        'ms=${stopwatch.elapsedMilliseconds}',
      );

      // ignore: avoid_print
      print(stackTrace);

      rethrow;
    }
  }

  test('01 - yalnızca kapak ve tek metrik', () async {
    await runCase(
      'minimal',
      MonitoringPdfReportData(
        title: 'Minimal Türkçe PDF Testi',
        subtitle: 'ğ ş ı İ ö ü ç karakterleri ve temel PDF üretimi.',
        fileNamePrefix: 'minimal_test',
        generatedAt: DateTime(2026, 7, 4, 21, 30),
        scoreLabel: 'Test Puanı',
        scoreValue: '100/100',
        metrics: const [MonitoringPdfMetric(label: 'Kaynak', value: '1')],
        sections: const [],
      ),
    );
  });

  test('02 - altı metrik, bölüm yok', () async {
    await runCase(
      'metrics_only',
      MonitoringPdfReportData(
        title: 'Metrik PDF Testi',
        subtitle: 'Altı metrik kartıyla sayfa yerleşimi testi.',
        fileNamePrefix: 'metrics_test',
        generatedAt: DateTime(2026, 7, 4, 21, 31),
        scoreLabel: 'Operasyon Sağlık Puanı',
        scoreValue: '100/100',
        metrics: const [
          MonitoringPdfMetric(label: 'Kaynak', value: '1'),
          MonitoringPdfMetric(label: 'İzlenen Sayfa', value: '1'),
          MonitoringPdfMetric(label: 'Tarama Görevi', value: '1'),
          MonitoringPdfMetric(label: 'İzleme Olayı', value: '0'),
          MonitoringPdfMetric(label: 'Risk Sinyali', value: '0'),
          MonitoringPdfMetric(label: 'Yüksek / Kritik', value: '0'),
        ],
        sections: const [],
      ),
    );
  });

  test('03 - metrik ve tek küçük bölüm', () async {
    await runCase(
      'one_section',
      MonitoringPdfReportData(
        title: 'Küçük Bölümlü PDF Testi',
        subtitle: 'Metrik ve küçük bölüm yerleşiminin testi.',
        fileNamePrefix: 'one_section_test',
        generatedAt: DateTime(2026, 7, 4, 21, 32),
        scoreLabel: 'Operasyon Sağlık Puanı',
        scoreValue: '100/100',
        metrics: const [
          MonitoringPdfMetric(label: 'Kaynak', value: '1'),
          MonitoringPdfMetric(label: 'İzlenen Sayfa', value: '1'),
          MonitoringPdfMetric(label: 'Tarama Görevi', value: '1'),
        ],
        sections: const [
          MonitoringPdfSection(
            title: 'Operasyon Durumu',
            rows: [
              MonitoringPdfRow(label: 'Sağlıklı kaynak', value: '1'),
              MonitoringPdfRow(label: 'Aktif izlenen sayfa', value: '1'),
            ],
          ),
        ],
      ),
    );
  });

  test('04 - yönetici özeti büyüklüğünde rapor', () async {
    await runCase(
      'executive_sized',
      MonitoringPdfReportData(
        title: 'Dijital Pazar Yönetici Özeti',
        subtitle:
            'İzleme kapsamı, operasyon sağlığı, değişiklik '
            'olayları ve risk sinyallerinin yönetim '
            'seviyesindeki özeti.',
        fileNamePrefix: 'executive_sized_test',
        generatedAt: DateTime(2026, 7, 4, 21, 33),
        scoreLabel: 'Operasyon Sağlık Puanı',
        scoreValue: '100/100',
        metrics: const [
          MonitoringPdfMetric(label: 'Kaynak', value: '1'),
          MonitoringPdfMetric(label: 'İzlenen Sayfa', value: '1'),
          MonitoringPdfMetric(label: 'Tarama Görevi', value: '1'),
          MonitoringPdfMetric(label: 'İzleme Olayı', value: '0'),
          MonitoringPdfMetric(label: 'Risk Sinyali', value: '0'),
          MonitoringPdfMetric(label: 'Yüksek / Kritik', value: '0'),
        ],
        sections: const [
          MonitoringPdfSection(
            title: 'Yönetim Değerlendirmesi',
            paragraphs: [
              'Genel operasyon görünümü istikrarlı durumdadır.',
              'İzleme kapsamı başlangıç seviyesinde olup '
                  'yeni kaynaklarla genişletilebilir.',
              'Mevcut verilerde yüksek veya kritik risk '
                  'sinyali bulunmamaktadır.',
            ],
          ),
          MonitoringPdfSection(
            title: 'Operasyon Durumu',
            rows: [
              MonitoringPdfRow(label: 'Sağlıklı kaynak', value: '1'),
              MonitoringPdfRow(label: 'Sorunlu kaynak', value: '0'),
              MonitoringPdfRow(label: 'Aktif izlenen sayfa', value: '1'),
              MonitoringPdfRow(label: 'Aktif tarama görevi', value: '1'),
              MonitoringPdfRow(label: 'Başarısızlık yaşayan sayfa', value: '0'),
            ],
          ),
          MonitoringPdfSection(
            title: 'Risk ve Olay Görünümü',
            rows: [
              MonitoringPdfRow(label: 'Yeni izleme olayı', value: '0'),
              MonitoringPdfRow(label: 'Yüksek / kritik olay', value: '0'),
              MonitoringPdfRow(label: 'Açık risk sinyali', value: '0'),
              MonitoringPdfRow(label: 'Yüksek / kritik sinyal', value: '0'),
              MonitoringPdfRow(label: 'İletim hatası', value: '0'),
            ],
          ),
          MonitoringPdfSection(
            title: 'Öncelikli Yönetim Aksiyonları',
            paragraphs: [
              'Mevcut verilere göre acil yönetim '
                  'aksiyonu gerekmiyor.',
            ],
          ),
        ],
      ),
    );
  });
}
