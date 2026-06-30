class RoomModel {
  final String id; // ID của phòng (Document ID trên Firestore)
  final String hotelId; // ID của khách sạn mà phòng này thuộc về
  final String providerId; // ID của chủ khách sạn (Dùng để phân quyền quản lý)
  final String roomNumber; // Số phòng (Ví dụ: 101, A-202)
  final String type; // Loại phòng (Single, Double, Suite, Deluxe...)
  final double price; // Giá thuê theo đêm
  final bool isAvailable; // Trạng thái phòng (Trống hay đã có người đặt)
  final List<String> images; // Danh sách hình ảnh của phòng
  final String description; // Mô tả chi tiết (Diện tích, tiện nghi...)
  final int maxGuests; // Số lượng khách tối đa

  RoomModel({
    required this.id,
    required this.hotelId,
    required this.providerId,
    required this.roomNumber,
    required this.type,
    required this.price,
    this.isAvailable = true,
    this.images = const [],
    this.description = '',
    this.maxGuests = 2,
  });

  // Chuyển dữ liệu từ Firestore (Map) sang Object RoomModel
  factory RoomModel.fromMap(Map<String, dynamic> data, String id) {
    return RoomModel(
      id: id,
      hotelId: data['hotelId'] ?? '',
      providerId: data['providerId'] ?? '',
      roomNumber: data['roomNumber'] ?? '',
      type: data['type'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      isAvailable: data['isAvailable'] ?? true,
      images: List<String>.from(data['images'] ?? []),
      description: data['description'] ?? '',
      maxGuests: data['maxGuests'] ?? 2,
    );
  }

  // Chuyển từ Object RoomModel sang Map để lưu lên Firestore
  Map<String, dynamic> toMap() {
    return {
      'hotelId': hotelId,
      'providerId': providerId,
      'roomNumber': roomNumber,
      'type': type,
      'price': price,
      'isAvailable': isAvailable,
      'images': images,
      'description': description,
      'maxGuests': maxGuests,
    };
  }
}
