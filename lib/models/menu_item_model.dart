class MenuItemModel {
  final String? id;
  final String penjualUid;
  final String nama;
  final double harga;

  MenuItemModel({
    this.id,
    required this.penjualUid,
    required this.nama,
    required this.harga,
  });

  factory MenuItemModel.fromMap(String id, Map<String, dynamic> data) {
    return MenuItemModel(
      id: id,
      penjualUid: data['penjual_uid'] ?? '',
      nama: data['nama'] ?? '',
      harga: (data['harga'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'penjual_uid': penjualUid,
    'nama': nama,
    'harga': harga,
  };
}
