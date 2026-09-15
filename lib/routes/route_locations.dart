String packingDetailLocation(String modelName, {bool showCatalog = true}) =>
    Uri(
      path: '/packing_detail',
      queryParameters: {'model': modelName, 'catalog': showCatalog.toString()},
    ).toString();

String packingCatalogLocation({
  required String assetPath,
  required int initialPage,
  required String modelName,
}) => Uri(
  path: '/packing_catalog_viewer',
  queryParameters: {
    'path': assetPath,
    'page': initialPage.toString(),
    'model': modelName,
  },
).toString();
