import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final SupabaseClient supabase;

  const PostCard({super.key, required this.post, required this.supabase});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  String? myReaction;
  Map<String, int> counts = {'like': 0, 'neutral': 0, 'dislike': 0};

  bool expanded = false;

  @override
  void initState() {
    super.initState();
    _loadReactions();
  }

  Future<void> _loadReactions() async {
    final user = widget.supabase.auth.currentUser;
    if (user == null) return;

    final res = await widget.supabase
        .from('post_reactions')
        .select('reaction')
        .eq('post_id', widget.post['id']);

    final Map<String, int> temp = {'like': 0, 'neutral': 0, 'dislike': 0};

    for (final r in res) {
      temp[r['reaction']] = (temp[r['reaction']] ?? 0) + 1;
    }

    final mine = await widget.supabase
        .from('post_reactions')
        .select()
        .eq('post_id', widget.post['id'])
        .eq('user_id', user.id)
        .maybeSingle();

    if (!mounted) return;
    setState(() {
      counts = temp;
      myReaction = mine?['reaction'];
    });
  }

  Future<void> _toggleReaction(String reaction) async {
    final user = widget.supabase.auth.currentUser;
    if (user == null) return;

    final existing = await widget.supabase
        .from('post_reactions')
        .select()
        .eq('post_id', widget.post['id'])
        .eq('user_id', user.id)
        .maybeSingle();

    if (existing != null && existing['reaction'] == reaction) {
      await widget.supabase
          .from('post_reactions')
          .delete()
          .eq('id', existing['id']);
    } else if (existing != null) {
      await widget.supabase
          .from('post_reactions')
          .update({'reaction': reaction})
          .eq('id', existing['id']);
    } else {
      await widget.supabase.from('post_reactions').insert({
        'post_id': widget.post['id'],
        'user_id': user.id,
        'reaction': reaction,
      });
    }

    await _loadReactions();
  }

  Widget _reactionButton(String type, IconData icon, Color color) {
    final active = myReaction == type;
    return InkWell(
      onTap: () => _toggleReaction(type),
      child: Row(
        children: [
          Icon(icon, color: active ? color : Colors.grey),
          const SizedBox(width: 4),
          Text(counts[type].toString()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final publishAt =
        DateTime.tryParse(widget.post['publish_at'] ?? '') ?? DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.post['title'],
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          Text(
            widget.post['content'],
            maxLines: expanded ? null : 3,
            overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),

          TextButton(
            onPressed: () => setState(() => expanded = !expanded),
            child: Text(expanded ? 'See less' : 'See more'),
          ),

          const Divider(),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _reactionButton('like', Icons.thumb_up, Colors.blue),
              _reactionButton(
                'neutral',
                Icons.sentiment_neutral,
                Colors.orange,
              ),
              _reactionButton('dislike', Icons.thumb_down, Colors.red),
            ],
          ),

          const SizedBox(height: 6),

          Text(
            'Published • ${publishAt.day}/${publishAt.month}/${publishAt.year}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
