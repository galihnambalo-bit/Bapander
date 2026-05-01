import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../utils/app_theme.dart';

class AvatarWidget extends StatelessWidget {
  final String name;
  final String photoUrl;
  final double size;

  const AvatarWidget({
    super.key,
    required this.name,
    required this.photoUrl,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty
        ? name.trim().split(' ').take(2).map((e) => e[0].toUpperCase()).join()
        : '?';

    final colors = [
      [const Color(0xFF9FE1CB), const Color(0xFF085041)],
      [const Color(0xFFFAC775), const Color(0xFF633806)],
      [const Color(0xFFB5D4F4), const Color(0xFF0C447C)],
      [const Color(0xFFCECBF6), const Color(0xFF3C3489)],
      [const Color(0xFFF5C4B3), const Color(0xFF712B13)],
      [const Color(0xFFC0DD97), const Color(0xFF27500A)],
    ];
    final colorPair = colors[name.hashCode.abs() % colors.length];

    if (photoUrl.isNotEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: photoUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: (ctx, url) => _initials(initials, colorPair, size),
            errorWidget: (ctx, url, err) => _initials(initials, colorPair, size),
          ),
        ),
      );
    }
    return _initials(initials, colorPair, size);
  }

  Widget _initials(
      String initials, List<Color> colorPair, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorPair[0],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: size * 0.36,
            fontWeight: FontWeight.w600,
            color: colorPair[1],
          ),
        ),
      ),
    );
  }
}
