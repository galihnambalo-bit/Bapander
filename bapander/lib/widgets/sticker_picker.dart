import 'package:flutter/material.dart';
import '../models/sticker_model.dart';
import '../utils/app_theme.dart';

class StickerPicker extends StatefulWidget {
  final Function(Sticker) onStickerSelected;

  const StickerPicker({super.key, required this.onStickerSelected});

  @override
  State<StickerPicker> createState() => _StickerPickerState();
}

class _StickerPickerState extends State<StickerPicker>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
        length: DefaultStickers.packs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Tab bar untuk pack
          TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            indicatorColor: AppTheme.primaryGreen,
            labelColor: AppTheme.primaryGreen,
            unselectedLabelColor: const Color(0xFF888780),
            tabs: DefaultStickers.packs.map((pack) =>
                Tab(text: '${pack.thumbnail} ${pack.name}')
            ).toList(),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: DefaultStickers.packs.map((pack) =>
                GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: pack.stickers.length,
                  itemBuilder: (ctx, i) {
                    final sticker = pack.stickers[i];
                    return GestureDetector(
                      onTap: () => widget.onStickerSelected(sticker),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F2F1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            sticker.emoji,
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      ),
                    );
                  },
                )
              ).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
