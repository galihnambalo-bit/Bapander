class StickerPack {
  final String id;
  final String name;
  final String thumbnail;
  final List<Sticker> stickers;

  const StickerPack({
    required this.id,
    required this.name,
    required this.thumbnail,
    required this.stickers,
  });
}

class Sticker {
  final String id;
  final String emoji;
  final String name;

  const Sticker({
    required this.id,
    required this.emoji,
    required this.name,
  });
}

// Default sticker packs pakai emoji (tidak butuh download)
class DefaultStickers {
  static const List<StickerPack> packs = [
    StickerPack(
      id: 'emotions',
      name: 'Ekspresi',
      thumbnail: '😀',
      stickers: [
        Sticker(id: 'e1', emoji: '😀', name: 'Senang'),
        Sticker(id: 'e2', emoji: '😂', name: 'Ngakak'),
        Sticker(id: 'e3', emoji: '🥹', name: 'Terharu'),
        Sticker(id: 'e4', emoji: '😍', name: 'Cinta'),
        Sticker(id: 'e5', emoji: '🤩', name: 'Kagum'),
        Sticker(id: 'e6', emoji: '😎', name: 'Keren'),
        Sticker(id: 'e7', emoji: '🥺', name: 'Minta'),
        Sticker(id: 'e8', emoji: '😭', name: 'Nangis'),
        Sticker(id: 'e9', emoji: '😤', name: 'Kesal'),
        Sticker(id: 'e10', emoji: '🤣', name: 'Guling'),
        Sticker(id: 'e11', emoji: '😱', name: 'Kaget'),
        Sticker(id: 'e12', emoji: '🤔', name: 'Mikir'),
        Sticker(id: 'e13', emoji: '😴', name: 'Ngantuk'),
        Sticker(id: 'e14', emoji: '🤯', name: 'Blow'),
        Sticker(id: 'e15', emoji: '🥳', name: 'Pesta'),
        Sticker(id: 'e16', emoji: '😅', name: 'Awkward'),
      ],
    ),
    StickerPack(
      id: 'gestures',
      name: 'Gerakan',
      thumbnail: '👍',
      stickers: [
        Sticker(id: 'g1', emoji: '👍', name: 'OKe'),
        Sticker(id: 'g2', emoji: '👎', name: 'Gak OKe'),
        Sticker(id: 'g3', emoji: '🙌', name: 'Yeay'),
        Sticker(id: 'g4', emoji: '👏', name: 'Tepuk'),
        Sticker(id: 'g5', emoji: '🤝', name: '握手'),
        Sticker(id: 'g6', emoji: '🫶', name: 'Love'),
        Sticker(id: 'g7', emoji: '✌️', name: 'Peace'),
        Sticker(id: 'g8', emoji: '🤞', name: 'Wish'),
        Sticker(id: 'g9', emoji: '👋', name: 'Halo'),
        Sticker(id: 'g10', emoji: '🙏', name: 'Makasih'),
        Sticker(id: 'g11', emoji: '💪', name: 'Kuat'),
        Sticker(id: 'g12', emoji: '🫵', name: 'Kamu'),
      ],
    ),
    StickerPack(
      id: 'banjar',
      name: 'Banjar',
      thumbnail: '🌿',
      stickers: [
        Sticker(id: 'b1', emoji: '🌿', name: 'Daun'),
        Sticker(id: 'b2', emoji: '🏡', name: 'Rumah Banjar'),
        Sticker(id: 'b3', emoji: '🛶', name: 'Perahu'),
        Sticker(id: 'b4', emoji: '🌴', name: 'Kelapa'),
        Sticker(id: 'b5', emoji: '🎋', name: 'Bambu'),
        Sticker(id: 'b6', emoji: '⛵', name: 'Layar'),
        Sticker(id: 'b7', emoji: '🌺', name: 'Bunga'),
        Sticker(id: 'b8', emoji: '🎑', name: 'Alam'),
        Sticker(id: 'b9', emoji: '🌾', name: 'Padi'),
        Sticker(id: 'b10', emoji: '🍚', name: 'Nasi'),
        Sticker(id: 'b11', emoji: '🐊', name: 'Buaya'),
        Sticker(id: 'b12', emoji: '🦜', name: 'Burung'),
      ],
    ),
  ];
}
