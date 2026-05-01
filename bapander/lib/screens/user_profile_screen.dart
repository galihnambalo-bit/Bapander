import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../utils/app_theme.dart';
import '../utils/supabase_config.dart';
import '../widgets/avatar_widget.dart';

class UserProfileScreen extends StatefulWidget {
  final String uid;
  const UserProfileScreen({super.key, required this.uid});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  bool _isFollowing = false;
  int _followersCount = 0;
  int _followingCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthService>();
    final user = await auth.getUserData(widget.uid);
    final isFollowing = await auth.isFollowing(auth.currentUid ?? '', widget.uid);
    final followers = await auth.getFollowersCount(widget.uid);
    final following = await auth.getFollowingCount(widget.uid);
    setState(() {
      _user = user;
      _isFollowing = isFollowing;
      _followersCount = followers;
      _followingCount = following;
      _loading = false;
    });
  }

  Future<void> _toggleFollow() async {
    final auth = context.read<AuthService>();
    final myUid = auth.currentUid ?? '';
    if (_isFollowing) {
      await auth.unfollowUser(myUid, widget.uid);
      setState(() { _isFollowing = false; _followersCount--; });
    } else {
      await auth.followUser(myUid, widget.uid);
      setState(() { _isFollowing = true; _followersCount++; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final myUid = auth.currentUid ?? '';
    final isMe = myUid == widget.uid;

    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final name = _user?['name'] ?? 'User';
    final photo = _user?['photo'] ?? '';
    final bio = _user?['bio'] ?? '';
    final online = _user?['online'] ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      body: CustomScrollView(
        slivers: [
          // ── APP BAR ────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: AppTheme.primaryGreen,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppTheme.primaryGreen, const Color(0xFF0A4F3E)],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              children: [
                // ── AVATAR ─────────────────────────────────────
                Transform.translate(
                  offset: const Offset(0, -50),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            child: AvatarWidget(name: name, photoUrl: photo, size: 90),
                          ),
                          if (online)
                            Positioned(
                              right: 4, bottom: 4,
                              child: Container(
                                width: 18, height: 18,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryLight,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(bio, textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFF888780), fontSize: 13)),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        online ? '🟢 Online' : '⚫ Offline',
                        style: TextStyle(
                          fontSize: 12,
                          color: online ? AppTheme.primaryGreen : const Color(0xFF888780),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── STATS ───────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _StatItem(count: _followersCount, label: 'Pengikut'),
                          Container(width: 1, height: 30, color: const Color(0xFFEEEEEE),
                              margin: const EdgeInsets.symmetric(horizontal: 24)),
                          _StatItem(count: _followingCount, label: 'Mengikuti'),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── ACTION BUTTONS ──────────────────────
                      if (!isMe)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _toggleFollow,
                                  icon: Icon(
                                    _isFollowing ? Icons.person_remove_rounded : Icons.person_add_rounded,
                                    size: 18,
                                  ),
                                  label: Text(_isFollowing ? 'Following' : 'Follow'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isFollowing
                                        ? const Color(0xFFF0F2F1)
                                        : AppTheme.primaryGreen,
                                    foregroundColor: _isFollowing
                                        ? const Color(0xFF888780)
                                        : Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final chatSvc = context.read<ChatService>();
                                    final chatId = await chatSvc.getOrCreateChat(myUid, widget.uid);
                                    if (context.mounted) {
                                      context.pop();
                                      context.push('/chat/$chatId', extra: {
                                        'name': name,
                                        'photo': photo,
                                        'uid': widget.uid,
                                      });
                                    }
                                  },
                                  icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                                  label: const Text('Pesan'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.primaryGreen,
                                    side: const BorderSide(color: AppTheme.primaryGreen),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),
                      const Divider(height: 1),
                    ],
                  ),
                ),

                // ── PRODUK USER ─────────────────────────────────
                FutureBuilder<List<dynamic>>(
                  future: SupabaseConfig.client
                      .from('products')
                      .select()
                      .eq('seller_id', widget.uid)
                      .eq('status', 'aktif')
                      .limit(6),
                  builder: (ctx, snap) {
                    final products = snap.data ?? [];
                    if (products.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text('Produk Dijual',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3, childAspectRatio: 0.85,
                            crossAxisSpacing: 8, mainAxisSpacing: 8,
                          ),
                          itemCount: products.length,
                          itemBuilder: (ctx, i) {
                            final p = products[i] as Map<String, dynamic>;
                            final images = (p['images'] as List? ?? []);
                            return GestureDetector(
                              onTap: () => context.push('/marketplace/product/${p['id']}'),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                                        child: images.isNotEmpty
                                            ? Image.network(images.first.toString(),
                                                fit: BoxFit.cover, width: double.infinity)
                                            : Container(color: const Color(0xFFF0F2F1),
                                                child: const Icon(Icons.image_rounded, color: Color(0xFFCCCCCC))),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: Text(p['title'] ?? '',
                                          maxLines: 1, overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final int count;
  final String label;
  const _StatItem({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$count', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF888780))),
      ],
    );
  }
}
