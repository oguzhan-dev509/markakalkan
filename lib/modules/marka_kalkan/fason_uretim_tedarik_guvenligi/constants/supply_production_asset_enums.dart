enum SupplyProductionAssetClass {
  physical('physical', 'Fiziksel'),
  digital('digital', 'Dijital'),
  hybrid('hybrid', 'Hibrit');

  const SupplyProductionAssetClass(this.value, this.label);
  final String value;
  final String label;

  static SupplyProductionAssetClass fromValue(String? value) {
    return values.firstWhere(
      (item) => item.value == value,
      orElse: () => SupplyProductionAssetClass.physical,
    );
  }
}

enum SupplyProductionAssetType {
  injectionMold('injection_mold', 'Enjeksiyon Kalıbı'),
  blowMold('blow_mold', 'Şişirme Kalıbı'),
  castingMold('casting_mold', 'Döküm Kalıbı'),
  pressDie('press_die', 'Pres Kalıbı'),
  cuttingDie('cutting_die', 'Kesim Kalıbı'),
  textilePattern('textile_pattern', 'Tekstil Şablonu'),
  printingPlate('printing_plate', 'Baskı Kalıbı'),
  printingCylinder('printing_cylinder', 'Baskı Silindiri'),
  tabletPunchDie('tablet_punch_die', 'Tablet Zımba Kalıbı'),
  pcbStencil('pcb_stencil', 'PCB Şablonu'),
  fixture('fixture', 'Fikstür'),
  gauge('gauge', 'Mastar'),
  assemblyTool('assembly_tool', 'Montaj Aparatı'),
  cncProgram('cnc_program', 'CNC Programı'),
  cadFile('cad_file', 'CAD Dosyası'),
  camFile('cam_file', 'CAM Dosyası'),
  threeDModel('three_d_model', '3B Model'),
  packagingArtwork('packaging_artwork', 'Ambalaj Tasarım Dosyası'),
  labelArtwork('label_artwork', 'Etiket Tasarım Dosyası'),
  other('other', 'Diğer');

  const SupplyProductionAssetType(this.value, this.label);
  final String value;
  final String label;

  static SupplyProductionAssetType fromValue(String? value) {
    return values.firstWhere(
      (item) => item.value == value,
      orElse: () => SupplyProductionAssetType.other,
    );
  }
}

enum SupplyProductionAssetStatus {
  draft('draft', 'Taslak'),
  active('active', 'Aktif'),
  inStorage('in_storage', 'Depoda'),
  inMaintenance('in_maintenance', 'Bakımda'),
  inTransfer('in_transfer', 'Transferde'),
  quarantined('quarantined', 'Karantinada'),
  retired('retired', 'Kullanımdan Kaldırıldı'),
  destroyed('destroyed', 'İmha Edildi'),
  archived('archived', 'Arşivlendi');

  const SupplyProductionAssetStatus(this.value, this.label);
  final String value;
  final String label;

  static SupplyProductionAssetStatus fromValue(String? value) {
    return values.firstWhere(
      (item) => item.value == value,
      orElse: () => SupplyProductionAssetStatus.draft,
    );
  }
}
