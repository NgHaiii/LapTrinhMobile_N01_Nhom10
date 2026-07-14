import 'package:flutter/material.dart';

class AccountHeaderCard extends StatelessWidget {
  const AccountHeaderCard({
    super.key,
    this.fullName = 'TravelHub Member',
    this.email = '',
    this.avatarUrl = '',
    this.memberTier = 'Bronze',
    this.points = 0,
  });

  final String fullName;
  final String email;
  final String avatarUrl;
  final String memberTier;
  final int points;

  @override
  Widget build(BuildContext context) {
    final avatar = avatarUrl.trim();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF073B42),
            Color(0xFF087F8C),
            Color(0xFFE76F51),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF087F8C).withOpacity(0.24),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -18,
            child: Icon(
              Icons.travel_explore_rounded,
              size: 132,
              color: Colors.white.withOpacity(0.12),
            ),
          ),
          Column(
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: avatar.isEmpty
                          ? const ColoredBox(
                              color: Colors.white,
                              child: Icon(
                                Icons.person_outline_rounded,
                                color: Color(0xFF087F8C),
                                size: 38,
                              ),
                            )
                          : Image.network(
                              avatar,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) {
                                return const ColoredBox(
                                  color: Colors.white,
                                  child: Icon(
                                    Icons.person_outline_rounded,
                                    color: Color(0xFF087F8C),
                                    size: 38,
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName.trim().isEmpty
                              ? 'TravelHub Member'
                              : fullName.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          email.trim().isEmpty
                              ? 'Quản lý hành trình của bạn'
                              : email.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.workspace_premium_rounded,
                      label: 'Hạng',
                      value: memberTier,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.stars_rounded,
                      label: 'Điểm',
                      value: '$points',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}