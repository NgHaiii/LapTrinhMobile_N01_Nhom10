import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/saved_place.dart';
import '../model/travel_place.dart';

class TravelPlaceService {
  TravelPlaceService({
    FirebaseFirestore? firestore,
    bool useLocalSamples = true,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _useLocalSamples = useLocalSamples;

  final FirebaseFirestore _firestore;
  final bool _useLocalSamples;

  CollectionReference<Map<String, dynamic>> get _placesRef {
    return _firestore.collection('travelPlaces');
  }

  CollectionReference<Map<String, dynamic>> get _savedPlacesRef {
    return _firestore.collection('savedPlaces');
  }

  Stream<List<TravelPlaceModel>> watchFeaturedPlaces({
    int limit = 10,
  }) {
    if (_useLocalSamples) {
      return Stream.value(
        _sortPlaces(
          samplePlaces
              .where((place) => place.isActive && place.isFeatured)
              .take(limit)
              .toList(),
        ),
      );
    }

    return _placesRef
        .where('isActive', isEqualTo: true)
        .where('isFeatured', isEqualTo: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return _sortPlaces(snapshot.docs.map(TravelPlaceModel.fromDoc).toList());
    });
  }

  Stream<List<TravelPlaceModel>> watchPlaces({
    TravelPlaceCategory? category,
    String province = '',
    String district = '',
    String keyword = '',
    bool onlyActive = true,
    int limit = 50,
  }) {
    if (_useLocalSamples) {
      final places = samplePlaces.where((place) {
        if (onlyActive && !place.isActive) return false;

        if (category != null &&
            category != TravelPlaceCategory.other &&
            place.category != category) {
          return false;
        }

        if (province.trim().isNotEmpty &&
            place.province.trim() != province.trim()) {
          return false;
        }

        if (district.trim().isNotEmpty &&
            place.district.trim() != district.trim()) {
          return false;
        }

        final normalizedKeyword = _normalize(keyword);
        if (normalizedKeyword.isEmpty) return true;

        final source = _normalize(
          '${place.name} ${place.description} ${place.fullAddress} '
          '${place.category.label} ${place.tags.join(' ')}',
        );

        return source.contains(normalizedKeyword);
      }).toList();

      return Stream.value(_sortPlaces(places.take(limit).toList()));
    }

    Query<Map<String, dynamic>> query = _placesRef;

    if (onlyActive) {
      query = query.where('isActive', isEqualTo: true);
    }

    if (category != null && category != TravelPlaceCategory.other) {
      query = query.where('category', isEqualTo: category.name);
    }

    if (province.trim().isNotEmpty) {
      query = query.where('province', isEqualTo: province.trim());
    }

    if (district.trim().isNotEmpty) {
      query = query.where('district', isEqualTo: district.trim());
    }

    return query.limit(limit).snapshots().map((snapshot) {
      final normalizedKeyword = _normalize(keyword);

      final places = snapshot.docs.map(TravelPlaceModel.fromDoc).where((place) {
        if (normalizedKeyword.isEmpty) return true;

        final source = _normalize(
          '${place.name} ${place.description} ${place.fullAddress} '
          '${place.category.label} ${place.tags.join(' ')}',
        );

        return source.contains(normalizedKeyword);
      }).toList();

      return _sortPlaces(places);
    });
  }

  Stream<TravelPlaceModel?> watchPlace(String placeId) {
    if (placeId.trim().isEmpty) {
      return Stream.value(null);
    }

    if (_useLocalSamples) {
      return Stream.value(getLocalPlace(placeId));
    }

    return _placesRef.doc(placeId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return TravelPlaceModel.fromDoc(doc);
    });
  }

  Future<TravelPlaceModel?> getPlace(String placeId) async {
    if (placeId.trim().isEmpty) return null;

    if (_useLocalSamples) {
      return getLocalPlace(placeId);
    }

    final doc = await _placesRef.doc(placeId).get();
    if (!doc.exists) return null;

    return TravelPlaceModel.fromDoc(doc);
  }

  TravelPlaceModel? getLocalPlace(String placeId) {
    for (final place in samplePlaces) {
      if (place.id == placeId) return place;
    }

    return null;
  }

  Stream<List<SavedPlaceModel>> watchSavedPlaces(String userId) {
    if (userId.trim().isEmpty) {
      return Stream.value(const []);
    }

    return _savedPlacesRef
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final saved = snapshot.docs.map(SavedPlaceModel.fromDoc).toList();

      saved.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return saved;
    });
  }

  Future<bool> isSaved({
    required String userId,
    required String placeId,
    SavedPlaceType type = SavedPlaceType.travelPlace,
  }) async {
    if (userId.trim().isEmpty || placeId.trim().isEmpty) return false;

    final id = _savedPlaceId(userId, placeId, type);
    final doc = await _savedPlacesRef.doc(id).get();

    return doc.exists;
  }

  Future<void> saveTravelPlace({
    required String userId,
    required TravelPlaceModel place,
    String note = '',
  }) async {
    if (userId.trim().isEmpty) {
      throw Exception('Bạn cần đăng nhập để lưu địa điểm.');
    }

    final saved = SavedPlaceModel(
      id: _savedPlaceId(userId, place.id, SavedPlaceType.travelPlace),
      userId: userId,
      placeId: place.id,
      name: place.name,
      type: SavedPlaceType.travelPlace,
      imageUrl: place.primaryImage,
      address: place.address,
      province: place.province,
      district: place.district,
      rating: place.rating,
      note: note.trim(),
    );

    await _savedPlacesRef.doc(saved.id).set(saved.toMap());
  }

  Future<void> removeSavedPlace({
    required String userId,
    required String placeId,
    SavedPlaceType type = SavedPlaceType.travelPlace,
  }) async {
    if (userId.trim().isEmpty || placeId.trim().isEmpty) return;

    await _savedPlacesRef.doc(_savedPlaceId(userId, placeId, type)).delete();
  }

  Future<void> toggleSavedTravelPlace({
    required String userId,
    required TravelPlaceModel place,
  }) async {
    final currentlySaved = await isSaved(
      userId: userId,
      placeId: place.id,
      type: SavedPlaceType.travelPlace,
    );

    if (currentlySaved) {
      await removeSavedPlace(
        userId: userId,
        placeId: place.id,
        type: SavedPlaceType.travelPlace,
      );
      return;
    }

    await saveTravelPlace(userId: userId, place: place);
  }

  String _savedPlaceId(
    String userId,
    String placeId,
    SavedPlaceType type,
  ) {
    return '${userId}_${type.name}_$placeId';
  }
}

List<TravelPlaceModel> _sortPlaces(List<TravelPlaceModel> places) {
  places.sort((a, b) {
    if (a.isFeatured != b.isFeatured) {
      return a.isFeatured ? -1 : 1;
    }

    final ratingCompare = b.rating.compareTo(a.rating);
    if (ratingCompare != 0) return ratingCompare;

    return b.reviewCount.compareTo(a.reviewCount);
  });

  return places;
}

String _normalize(String value) {
  return value.trim().toLowerCase();
}

const List<TravelPlaceModel> samplePlaces = [
  TravelPlaceModel(
    id: 'ha_giang_dong_van',
    name: 'Hà Giang hùng vĩ',
    description:
        'Hà Giang là nơi dành cho những chuyến đi thật sự có cảm giác phiêu lưu. Những cung đường quanh co qua cao nguyên đá Đồng Văn, đèo Mã Pì Lèng và dòng Nho Quế xanh ngọc tạo nên một hành trình rất khó quên. '
        'Buổi sáng có thể săn mây trên các triền núi, ban ngày chạy xe qua những bản làng vùng cao, còn chiều xuống là khoảnh khắc đẹp nhất để ngắm núi đá chuyển màu trong nắng. '
        'Nếu đi vào mùa hoa tam giác mạch hoặc mùa lúa chín, cảnh sắc Hà Giang càng rực rỡ hơn. Đây là lựa chọn phù hợp cho nhóm bạn thích khám phá, chụp ảnh, trải nghiệm văn hóa bản địa và muốn có một chuyến đi nhiều cảm xúc.',
    province: 'Hà Giang',
    district: 'Đồng Văn',
    address: 'Cao nguyên đá Đồng Văn',
    category: TravelPlaceCategory.mountain,
    images: [
      'assets/images/travel/Ha_Giang/1.png',
      'assets/images/travel/Ha_Giang/2.png',
      'assets/images/travel/Ha_Giang/3.png',
      'assets/images/travel/Ha_Giang/4.png',
    ],
    openingHours: 'Cả ngày',
    ticketPrice: 0,
    rating: 4.9,
    reviewCount: 1680,
    isFeatured: true,
    tags: [
      'phượt',
      'núi rừng',
      'đèo',
      'săn mây',
      'tam giác mạch',
      'sông Nho Quế',
    ],
  ),
  TravelPlaceModel(
    id: 'nha_trang_bien_dao',
    name: 'Nha Trang biển xanh',
    description:
        'Nha Trang là điểm đến lý tưởng cho những ai muốn một kỳ nghỉ biển sôi động, dễ đi và nhiều trải nghiệm. Thành phố có bãi biển dài, nước xanh, nhiều đảo đẹp và hệ sinh thái vui chơi rất phù hợp cho cả gia đình, cặp đôi lẫn nhóm bạn. '
        'Bạn có thể bắt đầu ngày mới bằng việc dạo biển Trần Phú, sau đó đi tour đảo Hòn Mun, Hòn Tằm, lặn ngắm san hô hoặc thư giãn tại các khu tắm bùn. Buổi tối là thời điểm tuyệt vời để thưởng thức hải sản, đi chợ đêm và ngắm thành phố lên đèn. '
        'Một lịch trình 3 ngày 2 đêm ở Nha Trang thường vừa đủ để tắm biển, vui chơi, ăn ngon và có nhiều ảnh đẹp mang về.',
    province: 'Khánh Hòa',
    district: 'Nha Trang',
    address: 'Khu vực vịnh Nha Trang',
    category: TravelPlaceCategory.beach,
    images: [
      'assets/images/travel/Nha_Trang/1.png',
      'assets/images/travel/Nha_Trang/2.png',
      'assets/images/travel/Nha_Trang/3.png',
      'assets/images/travel/Nha_Trang/4.png',
      'assets/images/travel/Nha_Trang/5.png',
    ],
    openingHours: 'Cả ngày',
    ticketPrice: 0,
    rating: 4.7,
    reviewCount: 1420,
    isFeatured: true,
    tags: ['biển đảo', 'lặn biển', 'san hô', 'vui chơi', 'hải sản'],
  ),
  TravelPlaceModel(
    id: 'hoi_an_ancient_town',
    name: 'Phố cổ Hội An',
    description:
        'Hội An mang vẻ đẹp cổ kính, chậm rãi và rất dễ khiến du khách muốn nán lại lâu hơn. Những con phố nhỏ phủ sắc vàng, giàn hoa giấy, mái ngói cũ và ánh đèn lồng vào buổi tối tạo nên không khí rất riêng. '
        'Ban ngày, bạn có thể đi bộ qua các nhà cổ, ghé quán cà phê, tham quan chùa Cầu hoặc đạp xe ra làng rau Trà Quế. Khi chiều xuống, phố cổ bắt đầu lên đèn, sông Hoài phản chiếu ánh sáng lung linh và trải nghiệm thả hoa đăng trở thành điểm nhấn đáng nhớ. '
        'Hội An còn rất hấp dẫn với cao lầu, mì Quảng, bánh mì, cơm gà và những góc chụp ảnh nhẹ nhàng phù hợp cho chuyến đi thư giãn.',
    province: 'Quảng Nam',
    district: 'Hội An',
    address: 'Trung tâm phố cổ Hội An',
    category: TravelPlaceCategory.culture,
    images: [
      'assets/images/travel/Hoi_An/1.png',
      'assets/images/travel/Hoi_An/2.png',
      'assets/images/travel/Hoi_An/3.png',
      'assets/images/travel/Hoi_An/4.png',
      'assets/images/travel/Hoi_An/5.png',
    ],
    openingHours: 'Cả ngày',
    ticketPrice: 120000,
    rating: 4.8,
    reviewCount: 1980,
    isFeatured: true,
    tags: ['văn hóa', 'đèn lồng', 'ẩm thực', 'đi bộ', 'sông Hoài'],
  ),
  TravelPlaceModel(
    id: 'da_lat_mong_mo',
    name: 'Đà Lạt mộng mơ',
    description:
        'Đà Lạt là điểm đến phù hợp cho những chuyến đi cần một chút mát lành, nhẹ nhàng và nhiều góc đẹp. Thành phố có hồ, đồi thông, quán cà phê nhìn ra thung lũng, chợ đêm và những cung đường ngoại ô rất thơ. '
        'Buổi sáng có thể săn mây ở Cầu Đất hoặc đồi chè, ban ngày ghé các điểm check-in, còn tối đến thưởng thức lẩu gà lá é, bánh tráng nướng và đồ nướng trong tiết trời se lạnh. '
        'Đà Lạt đặc biệt hợp với cặp đôi, nhóm bạn và những ai thích chụp ảnh, nghỉ dưỡng chậm rãi, uống cà phê đẹp và tận hưởng cảm giác rời xa nhịp sống ồn ào.',
    province: 'Lâm Đồng',
    district: 'Đà Lạt',
    address: 'Trung tâm thành phố Đà Lạt',
    category: TravelPlaceCategory.mountain,
    images: [
      'assets/images/travel/Da_Lat/1.png',
      'assets/images/travel/Da_Lat/2.png',
      'assets/images/travel/Da_Lat/3.png',
      'assets/images/travel/Da_Lat/4.png',
      'assets/images/travel/Da_Lat/5.png',
    ],
    openingHours: 'Cả ngày',
    ticketPrice: 0,
    rating: 4.7,
    reviewCount: 1540,
    isFeatured: true,
    tags: ['cao nguyên', 'cà phê', 'check-in', 'khí hậu mát', 'săn mây'],
  ),
  TravelPlaceModel(
    id: 'quy_nhon_ky_co',
    name: 'Kỳ Co Quy Nhơn',
    description:
        'Quy Nhơn có vẻ đẹp trong trẻo, ít xô bồ hơn nhiều thành phố biển lớn, nhưng vẫn đủ đầy trải nghiệm cho một chuyến nghỉ dưỡng đáng nhớ. Kỳ Co nổi bật với nước biển trong, bãi cát sáng và khung cảnh rất hợp để chụp ảnh. '
        'Du khách thường kết hợp Kỳ Co với Eo Gió, Hòn Khô, tháp Chăm và các quán hải sản địa phương. Nhịp du lịch ở Quy Nhơn khá dễ chịu, chi phí hợp lý, phù hợp cho gia đình, nhóm bạn hoặc cặp đôi muốn tìm một điểm biển đẹp nhưng không quá đông. '
        'Nếu thích cảm giác biển xanh, nắng vàng, ăn ngon và lịch trình nhẹ nhàng, Quy Nhơn là lựa chọn rất đáng cân nhắc.',
    province: 'Bình Định',
    district: 'Quy Nhơn',
    address: 'Kỳ Co, Nhơn Lý',
    category: TravelPlaceCategory.beach,
    images: [
      'assets/images/travel/Quy_Nhon/1.png',
      'assets/images/travel/Quy_Nhon/2.png',
      'assets/images/travel/Quy_Nhon/3.png',
      'assets/images/travel/Quy_Nhon/4.png',
      'assets/images/travel/Quy_Nhon/5.png',
    ],
    openingHours: '07:00 - 17:00',
    ticketPrice: 150000,
    rating: 4.7,
    reviewCount: 980,
    isFeatured: true,
    tags: ['biển', 'Kỳ Co', 'Eo Gió', 'nghỉ dưỡng', 'hải sản'],
  ),
  TravelPlaceModel(
    id: 'ninh_binh_trang_an',
    name: 'Tràng An Ninh Bình',
    description:
        'Tràng An là nơi thiên nhiên hiện ra rất điện ảnh với sông nước, núi đá vôi, hang động và những chuyến thuyền len qua cảnh quan xanh mát. Cảm giác ngồi thuyền giữa mặt nước yên, hai bên là núi đá và cây cối tạo nên một trải nghiệm thư giãn nhưng vẫn rất ấn tượng. '
        'Bạn có thể kết hợp Tràng An với Hang Múa để ngắm toàn cảnh, cố đô Hoa Lư để tìm hiểu lịch sử và Tam Cốc nếu muốn thêm một cung đường sông nước khác. '
        'Ninh Bình rất hợp cho chuyến đi cuối tuần từ Hà Nội, đặc biệt với khách thích thiên nhiên, chụp ảnh, đi nhẹ nhàng nhưng vẫn có nhiều trải nghiệm.',
    province: 'Ninh Bình',
    district: 'Hoa Lư',
    address: 'Khu du lịch sinh thái Tràng An',
    category: TravelPlaceCategory.nature,
    images: [
      'assets/images/travel/Ninh_Binh/1.png',
      'assets/images/travel/Ninh_Binh/2.png',
      'assets/images/travel/Ninh_Binh/3.png',
      'assets/images/travel/Ninh_Binh/4.png',
      'assets/images/travel/Ninh_Binh/5.png',
    ],
    openingHours: '07:00 - 16:30',
    ticketPrice: 250000,
    rating: 4.8,
    reviewCount: 1760,
    isFeatured: true,
    tags: ['thuyền', 'hang động', 'thiên nhiên', 'di sản', 'cuối tuần'],
  ),
  TravelPlaceModel(
    id: 'da_nang_my_khe',
    name: 'Đà Nẵng năng động',
    description:
        'Đà Nẵng là thành phố biển dễ đi, sạch đẹp và rất phù hợp cho chuyến du lịch đầu tiên cùng gia đình hoặc bạn bè. Buổi sáng có thể tắm biển Mỹ Khê, chiều ghé bán đảo Sơn Trà, tối ngắm cầu Rồng hoặc thưởng thức hải sản ven biển. '
        'Điểm hay của Đà Nẵng là lịch trình rất linh hoạt: muốn nghỉ dưỡng có biển và resort, muốn vui chơi có Bà Nà Hills, muốn khám phá văn hóa có thể kết hợp Hội An hoặc Huế. '
        'Thành phố này tạo cảm giác trẻ trung, tiện lợi và an toàn, đặc biệt phù hợp cho khách muốn một chuyến đi vừa thư giãn vừa có nhiều hoạt động.',
    province: 'Đà Nẵng',
    district: 'Sơn Trà',
    address: 'Võ Nguyên Giáp',
    category: TravelPlaceCategory.beach,
    images: [
      'assets/images/travel/Da_Nang/1.png',
      'assets/images/travel/Da_Nang/2.png',
      'assets/images/travel/Da_Nang/3.png',
      'assets/images/travel/Da_Nang/4.png',
    ],
    openingHours: 'Cả ngày',
    ticketPrice: 0,
    rating: 4.8,
    reviewCount: 1280,
    isFeatured: true,
    tags: ['biển', 'cầu Rồng', 'Sơn Trà', 'gia đình', 'ẩm thực'],
  ),
  TravelPlaceModel(
    id: 'ha_long_bay',
    name: 'Vịnh Hạ Long',
    description:
        'Vịnh Hạ Long là một trong những điểm đến biểu tượng của du lịch Việt Nam với làn nước xanh, hàng nghìn đảo đá vôi và khung cảnh rất hùng vĩ. Trải nghiệm đáng thử nhất là đi du thuyền, ngắm hoàng hôn trên vịnh, tham quan hang động và chèo kayak giữa không gian yên bình. '
        'Nếu có thời gian, lịch trình 2 ngày 1 đêm trên du thuyền sẽ giúp chuyến đi trọn vẹn hơn vì bạn được ngắm vịnh vào cả buổi chiều, tối và sáng sớm. '
        'Hạ Long phù hợp cho cặp đôi, gia đình hoặc nhóm khách muốn một hành trình nghỉ dưỡng có điểm nhấn sang trọng, nhiều ảnh đẹp và cảm giác thật sự khác biệt.',
    province: 'Quảng Ninh',
    district: 'Hạ Long',
    address: 'Thành phố Hạ Long',
    category: TravelPlaceCategory.nature,
    images: [
      'assets/images/travel/Ha_Long/1.png',
      'assets/images/travel/Ha_Long/2.png',
      'assets/images/travel/Ha_Long/3.png',
      'assets/images/travel/Ha_Long/4.png',
      'assets/images/travel/Ha_Long/5.png',
      'assets/images/travel/Ha_Long/6.png',
      'assets/images/travel/Ha_Long/7.png',
    ],
    openingHours: '07:00 - 17:00',
    ticketPrice: 290000,
    rating: 4.9,
    reviewCount: 2450,
    isFeatured: true,
    tags: ['du thuyền', 'hang động', 'di sản', 'thiên nhiên', 'kayak'],
  ),
  TravelPlaceModel(
    id: 'sapa_fansipan',
    name: 'Sa Pa săn mây',
    description:
        'Sa Pa hấp dẫn bởi khí hậu mát lạnh, những thửa ruộng bậc thang, bản làng vùng cao và cảm giác thức dậy giữa màn sương núi. Fansipan là điểm nhấn lớn cho những ai muốn chạm tới nóc nhà Đông Dương, còn bản Cát Cát, thung lũng Mường Hoa và đèo Ô Quy Hồ lại mang đến vẻ đẹp rất đời thường của vùng núi Tây Bắc. '
        'Một chuyến đi Sa Pa nên có thời gian thong thả để dạo bản, uống cà phê ngắm núi, thử món địa phương và săn mây vào sáng sớm. '
        'Đây là địa điểm phù hợp với khách thích không khí se lạnh, cảnh núi, ảnh đẹp và trải nghiệm văn hóa bản địa.',
    province: 'Lào Cai',
    district: 'Sa Pa',
    address: 'Khu du lịch Fansipan Legend',
    category: TravelPlaceCategory.mountain,
    images: [
      'assets/images/travel/Sa_Pa/1.png',
      'assets/images/travel/Sa_Pa/2.png',
      'assets/images/travel/Sa_Pa/3.png',
      'assets/images/travel/Sa_Pa/4.png',
      'assets/images/travel/Sa_Pa/5.png',
    ],
    openingHours: '07:30 - 17:30',
    ticketPrice: 800000,
    rating: 4.7,
    reviewCount: 1320,
    isFeatured: true,
    tags: ['núi rừng', 'săn mây', 'cáp treo', 'khí hậu mát', 'bản làng'],
  ),
  TravelPlaceModel(
    id: 'hue_imperial_city',
    name: 'Huế trầm mặc',
    description:
        'Huế là điểm đến dành cho những ai thích lịch sử, kiến trúc cổ và nhịp du lịch chậm rãi. Đại Nội, chùa Thiên Mụ, sông Hương, các lăng tẩm và những con đường rợp bóng cây tạo nên một không gian rất riêng, nhẹ nhàng nhưng sâu sắc. '
        'Du khách đến Huế không chỉ để tham quan di tích mà còn để thưởng thức ẩm thực: bún bò Huế, cơm hến, bánh bèo, bánh nậm, chè Huế. Buổi tối có thể đi dạo bên sông Hương hoặc nghe ca Huế để cảm nhận rõ hơn chất thơ của thành phố. '
        'Huế rất hợp với lịch trình văn hóa, nghỉ dưỡng nhẹ và những chuyến đi muốn tìm cảm giác bình yên.',
    province: 'Thừa Thiên Huế',
    district: 'Huế',
    address: 'Đường 23 Tháng 8',
    category: TravelPlaceCategory.culture,
    images: [
      'assets/images/travel/Hue/1.png',
      'assets/images/travel/Hue/2.png',
      'assets/images/travel/Hue/3.png',
      'assets/images/travel/Hue/4.png',
      'assets/images/travel/Hue/5.png',
    ],
    openingHours: '07:00 - 17:30',
    ticketPrice: 200000,
    rating: 4.6,
    reviewCount: 960,
    isFeatured: true,
    tags: ['lịch sử', 'cung đình', 'sông Hương', 'ẩm thực Huế', 'di sản'],
  ),
  TravelPlaceModel(
    id: 'phu_quoc_sao_beach',
    name: 'Phú Quốc nghỉ dưỡng',
    description:
        'Phú Quốc là lựa chọn tuyệt vời cho một kỳ nghỉ biển đúng nghĩa: có bãi biển đẹp, resort, hoàng hôn rực rỡ, tour đảo và nhiều khu vui chơi lớn. Bãi Sao, Hòn Thơm, Sunset Town, Grand World và chợ đêm là những điểm có thể đưa vào lịch trình 3-4 ngày. '
        'Ban ngày có thể đi tour đảo, lặn ngắm san hô hoặc vui chơi tại công viên giải trí; chiều tối là thời điểm lý tưởng để ngắm hoàng hôn, ăn hải sản và dạo phố biển. '
        'Phú Quốc phù hợp với gia đình, cặp đôi và nhóm bạn muốn một chuyến đi nghỉ dưỡng thoải mái, nhiều dịch vụ, dễ đặt phòng và nhiều trải nghiệm trong cùng một điểm đến.',
    province: 'Kiên Giang',
    district: 'Phú Quốc',
    address: 'Khu vực Bãi Sao, An Thới',
    category: TravelPlaceCategory.beach,
    images: [
      'assets/images/travel/Phu_Quoc/1.png',
      'assets/images/travel/Phu_Quoc/2.png',
      'assets/images/travel/Phu_Quoc/3.png',
      'assets/images/travel/Phu_Quoc/4.png',
      'assets/images/travel/Phu_Quoc/5.png',
    ],
    openingHours: 'Cả ngày',
    ticketPrice: 0,
    rating: 4.7,
    reviewCount: 1100,
    isFeatured: true,
    tags: ['biển', 'nghỉ dưỡng', 'hoàng hôn', 'gia đình', 'tour đảo'],
  ),
];