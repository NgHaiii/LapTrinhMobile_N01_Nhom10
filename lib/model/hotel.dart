class HotelModel {
  final String id;
  final String providerId; // ID của chủ khách sạn (Dùng để lọc dữ liệu)
  final String name;       // Đã sửa lỗi dính comment
  final String address;
  final String description;
  final String imageUrl;
  final double rating;

  HotelModel({
    required this.id,
    required this.providerId,
    required this.name,
    required this.address,
    required this.description,
    required this.imageUrl,
    this.rating = 0.0,
  });

  factory HotelModel.fromMap(Map<String, dynamic> data, String id) {
    return HotelModel(
      id: id,
      providerId: data['providerId'] ?? '',
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'providerId': providerId,
      'name': name,
      'address': address,
      'description': description,
      'imageUrl': imageUrl,
      'rating': rating,
    };
  }
}