import '../widgets/editable_material_table.dart';
import 'install_kit.dart';
import 'pipe_engine.dart';

/// Danh mục vật tư để chọn khi thêm tay: mọi vật tư trong file PO (cụm máy,
/// van xả, điện, mọi công suất) và định mức đường ống (mọi cỡ), bỏ trùng
/// (cùng mã, tên, quy cách, ĐVT), sắp theo tên.
List<CatalogMaterial> buildMaterialCatalog({
  InstallKits? kits,
  PipeRunKit? run,
}) {
  final seen = <String>{};
  final out = <CatalogMaterial>[];
  void add(String? code, String name, String unit, String? spec) {
    final key = [code ?? '', name, unit, spec ?? ''].join('|');
    if (seen.add(key)) {
      out.add(CatalogMaterial(code: code, name: name, unit: unit, spec: spec));
    }
  }

  for (final kit in kits?.kits ?? const <InstallKit>[]) {
    for (final section in [kit.standard, kit.drain, kit.electric]) {
      for (final i in section.items) {
        add(i.code, i.name, i.unit, i.spec);
      }
    }
  }
  for (final item in run?.items ?? const <PipeRunItem>[]) {
    for (final v in [?item.variant, ...item.sizes.values]) {
      add(v.code, v.name, item.unit, v.spec);
    }
  }
  out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return out;
}
