import 'package:flutter/material.dart';

import '../../../recipes/view/widgets/recipe_image.dart';
import '../../data/profile_repository.dart';

/// Ảnh đại diện tròn: ảnh đã tải lên, hoặc chữ cái đầu trên nền chuyển màu cam.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.profile, this.radius = 24});

  final UserProfile? profile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final initials = Container(
      key: const Key('avatar_initials'),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [Color(0xFFFFB74D), Color(0xFFEF6C00)],
        ),
      ),
      child: Text(
        profile?.initials ?? '',
        style: TextStyle(color: Colors.white, fontSize: radius * 0.8, fontWeight: FontWeight.w800),
      ),
    );
    final bytes = profile?.avatarBytes;
    if (bytes != null) {
      return ClipOval(
        key: const Key('avatar_photo'),
        child: Image.memory(bytes, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true,
            errorBuilder: (_, __, ___) => initials),
      );
    }
    final url = profile?.avatarUrl;
    if (url == null) return initials;
    return RecipeImage(key: const Key('avatar_photo'), url: url, width: size, height: size, borderRadius: radius, fallback: initials);
  }
}
