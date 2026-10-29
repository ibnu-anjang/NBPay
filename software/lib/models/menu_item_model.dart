class MenuItemModel {
  final String? id;
  final String penjualUid;
  final String nama;
  final double harga;
  final String? imageUrl;

  MenuItemModel({
    this.id,
    required this.penjualUid,
    required this.nama,
    required this.harga,
    this.imageUrl,
  });

  factory MenuItemModel.fromMap(String id, Map<String, dynamic> data) {
    return MenuItemModel(
      id: id,
      penjualUid: data['penjual_uid'] ?? '',
      nama: data['nama'] ?? '',
      harga: (data['harga'] ?? 0).toDouble(),
      imageUrl: data['image_url'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'penjual_uid': penjualUid,
    'nama': nama,
    'harga': harga,
    if (imageUrl != null && imageUrl!.isNotEmpty) 'image_url': imageUrl,
  };
}
