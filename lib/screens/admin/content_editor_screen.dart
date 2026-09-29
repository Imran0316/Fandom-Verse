import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/content_docs.dart';
import '../../services/content_service.dart';
import '../../services/image_upload_service.dart';
import '../../services/stream_cache.dart';
import '../../services/taxonomy_service.dart';
import '../../widgets/cached_image.dart';
import '../../widgets/glass_button.dart';

/// Create / edit a fandom discovery. Organised into Basic Information,
/// Classification, Media and Publishing sections.
class ContentEditorScreen extends StatefulWidget {
  const ContentEditorScreen({super.key, this.existing});

  final ContentDoc? existing;

  @override
  State<ContentEditorScreen> createState() => _ContentEditorScreenState();
}

class _ContentEditorScreenState extends State<ContentEditorScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _summary;
  late final TextEditingController _body;
  late final TextEditingController _question;
  late final TextEditingController _answer;
  late final TextEditingController _explanation;
  final TextEditingController _tagInput = TextEditingController();
  late final TextEditingController _videoUrl;

  late ContentType _type;
  late ContentStatus _status;
  late bool _isFeatured;
  late bool _isTrending;
  String? _fandomId;
  String _fandomName = '';
  String? _categoryId;
  String _categoryName = '';
  late List<String> _tags;
  String? _coverUrl;
  bool _uploading = false;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? ContentType.article;
    _status = e?.status ?? ContentStatus.draft;
    _isFeatured = e?.isFeatured ?? false;
    _isTrending = e?.isTrending ?? false;
    _fandomId = (e?.fandomId.isEmpty ?? true) ? null : e!.fandomId;
    _fandomName = e?.fandomName ?? '';
    _categoryId = (e?.categoryId.isEmpty ?? true) ? null : e!.categoryId;
    _categoryName = e?.categoryName ?? '';
    _tags = List<String>.from(e?.tags ?? const []);
    _coverUrl = e?.coverImageUrl;

    _title = TextEditingController(text: e?.title ?? '');
    _summary = TextEditingController(text: e?.summary ?? '');
    _body = TextEditingController(text: e?.body ?? '');
    _question = TextEditingController(text: e?.question ?? '');
    _answer = TextEditingController(text: e?.answer ?? '');
    _explanation = TextEditingController(text: e?.explanation ?? '');
    _videoUrl = TextEditingController(text: e?.videoUrl ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _body.dispose();
    _question.dispose();
    _answer.dispose();
    _explanation.dispose();
    _tagInput.dispose();
    _videoUrl.dispose();
    super.dispose();
  }

  void _toast(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xE616161F),
          content: Text(message),
          action: action,
        ),
      );
  }

  void _addTag(String raw) {
    final value = raw.trim().replaceAll('#', '');
    if (value.isEmpty || _tags.contains(value)) {
      _tagInput.clear();
      return;
    }
    setState(() => _tags = [..._tags, value]);
    _tagInput.clear();
  }

  Future<void> _pickCover() async {
    if (_uploading) return;
    setState(() => _uploading = true);
    try {
      final url = await ImageUploadService.instance.pickAndUpload(
        name: 'content-cover-${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!mounted) return;
      if (url != null) setState(() => _coverUrl = url);
    } catch (error) {
      debugPrint('Cover upload failed: $error');
      if (mounted) {
        _toast(
          ImageUploadService.friendlyMessage(error),
          action: SnackBarAction(
            label: 'Retry',
            textColor: AppColors.accent,
            onPressed: _pickCover,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save({bool? forcePublish}) async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_fandomId == null || _fandomId!.isEmpty) {
      _toast('Select a fandom for this discovery.');
      return;
    }
    if (_categoryId == null || _categoryId!.isEmpty) {
      _toast('Select a category for this discovery.');
      return;
    }
    if (_coverUrl == null && _uploading) {
      _toast('Wait for the cover image to finish uploading.');
      return;
    }

    final status = forcePublish == null
        ? _status
        : (forcePublish ? ContentStatus.published : ContentStatus.draft);
    // An emptied field clears the video on the saved doc.
    final videoUrl = _videoUrl.text.trim();

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await ContentService.instance.updateContent(
          widget.existing!.id,
          type: _type,
          title: _title.text,
          summary: _summary.text,
          body: _body.text,
          question: _question.text,
          answer: _answer.text,
          explanation: _explanation.text,
          fandomId: _fandomId!,
          fandomName: _fandomName,
          categoryId: _categoryId!,
          categoryName: _categoryName,
          tags: _tags,
          status: status,
          isFeatured: _isFeatured,
          isTrending: _isTrending,
          coverImageUrl: _coverUrl,
          videoUrl: videoUrl.isEmpty ? null : videoUrl,
          existingPublishedAt: widget.existing!.publishedAt,
        );
      } else {
        await ContentService.instance.createContent(
          type: _type,
          title: _title.text,
          summary: _summary.text,
          body: _body.text,
          question: _question.text,
          answer: _answer.text,
          explanation: _explanation.text,
          fandomId: _fandomId!,
          fandomName: _fandomName,
          categoryId: _categoryId!,
          categoryName: _categoryName,
          tags: _tags,
          status: status,
          isFeatured: _isFeatured,
          isTrending: _isTrending,
          coverImageUrl: _coverUrl,
          videoUrl: videoUrl.isEmpty ? null : videoUrl,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('Could not save content. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SafeArea(
            child: Column(
              children: [
                _header(),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                      children: [
                        _SectionA(
                          type: _type,
                          onTypeChanged: (t) => setState(() => _type = t),
                          title: _title,
                          summary: _summary,
                          body: _body,
                          question: _question,
                          answer: _answer,
                          explanation: _explanation,
                        ),
                        const SizedBox(height: 26),
                        _SectionB(
                          fandomId: _fandomId,
                          categoryId: _categoryId,
                          onFandomChanged: (id, name) => setState(() {
                            _fandomId = id;
                            _fandomName = name;
                          }),
                          onCategoryChanged: (id, name) => setState(() {
                            _categoryId = id;
                            _categoryName = name;
                          }),
                          tagInput: _tagInput,
                          tags: _tags,
                          onAddTag: _addTag,
                          onRemoveTag: (t) =>
                              setState(() => _tags = [..._tags]..remove(t)),
                        ),
                        const SizedBox(height: 26),
                        _SectionMedia(
                          coverUrl: _coverUrl,
                          uploading: _uploading,
                          onPick: _pickCover,
                          onRemove: () => setState(() => _coverUrl = null),
                          onUrlSubmitted: (url) =>
                              setState(() => _coverUrl = url),
                          videoUrl: _videoUrl,
                        ),
                        const SizedBox(height: 26),
                        _SectionD(
                          status: _status,
                          isFeatured: _isFeatured,
                          isTrending: _isTrending,
                          onStatusChanged: (s) => setState(() => _status = s),
                          onFeaturedChanged: (v) =>
                              setState(() => _isFeatured = v),
                          onTrendingChanged: (v) =>
                              setState(() => _isTrending = v),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                _actionBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing ? 'Edit Content' : 'Create Content',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _isEditing
                      ? 'Update this fandom discovery'
                      : 'Add a new discovery to the library',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          if (_status.isPublished)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.5),
                ),
              ),
              child: const Text(
                'PUBLISHED',
                style: TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundDeep,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: _isEditing
          ? Row(
              children: [
                Expanded(
                  child: GlassButton(
                    label: 'Cancel',
                    variant: GlassButtonVariant.outline,
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).maybePop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassButton(
                    label: 'Save Changes',
                    isLoading: _saving,
                    onPressed: () => _save(),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: GlassButton(
                    label: 'Save Draft',
                    variant: GlassButtonVariant.outline,
                    onPressed: _saving ? null : () => _save(forcePublish: false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassButton(
                    label: 'Publish',
                    isLoading: _saving,
                    onPressed: () => _save(forcePublish: true),
                  ),
                ),
              ],
            ),
    );
  }
}

/* ------------------------------- Section A ------------------------------- */

class _SectionA extends StatelessWidget {
  const _SectionA({
    required this.type,
    required this.onTypeChanged,
    required this.title,
    required this.summary,
    required this.body,
    required this.question,
    required this.answer,
    required this.explanation,
  });

  final ContentType type;
  final ValueChanged<ContentType> onTypeChanged;
  final TextEditingController title;
  final TextEditingController summary;
  final TextEditingController body;
  final TextEditingController question;
  final TextEditingController answer;
  final TextEditingController explanation;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Basic Information',
      subtitle: 'What is this discovery about?',
      children: [
        const _FieldLabel('CONTENT TYPE'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in ContentType.values)
              _TypeChip(
                type: t,
                selected: type == t,
                onTap: () => onTypeChanged(t),
              ),
          ],
        ),
        const SizedBox(height: 18),
        _EditorField(
          controller: title,
          label: 'Title *',
          hint: 'e.g. 10 Hidden Facts About One Piece',
          validator: (v) =>
              (v == null || v.trim().length < 3) ? 'Title is required' : null,
        ),
        const SizedBox(height: 16),
        _EditorField(
          controller: summary,
          label: 'Short description',
          hint: 'A one-line hook shown on cards',
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        if (type.usesQuestion) ...[
          _EditorField(
            controller: question,
            label: 'Question *',
            hint: 'What does this trivia ask?',
            maxLines: 2,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Question is required' : null,
          ),
          const SizedBox(height: 16),
          _EditorField(
            controller: answer,
            label: 'Answer *',
            hint: 'The reveal',
            maxLines: 2,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Answer is required' : null,
          ),
          const SizedBox(height: 16),
          _EditorField(
            controller: explanation,
            label: 'Explanation',
            hint: 'Why does it matter?',
            maxLines: 4,
          ),
        ] else
          _EditorField(
            controller: body,
            label: 'Body *',
            hint: 'Write the full story…',
            maxLines: 10,
            validator: (v) =>
                (v == null || v.trim().length < 10) ? 'Body is required' : null,
          ),
      ],
    );
  }
}

/* ------------------------------- Section B ------------------------------- */

class _SectionB extends StatefulWidget {
  const _SectionB({
    required this.fandomId,
    required this.categoryId,
    required this.onFandomChanged,
    required this.onCategoryChanged,
    required this.tagInput,
    required this.tags,
    required this.onAddTag,
    required this.onRemoveTag,
  });

  final String? fandomId;
  final String? categoryId;
  final void Function(String id, String name) onFandomChanged;
  final void Function(String id, String name) onCategoryChanged;
  final TextEditingController tagInput;
  final List<String> tags;
  final ValueChanged<String> onAddTag;
  final ValueChanged<String> onRemoveTag;

  @override
  State<_SectionB> createState() => _SectionBState();
}

class _SectionBState extends State<_SectionB> {
  final _fandoms = StreamCache<List<FandomDoc>>(
    () => TaxonomyService.instance.watchFandoms(),
  );
  final _categories = StreamCache<List<ContentCategoryDoc>>(
    () => TaxonomyService.instance.watchCategories(),
  );

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Classification',
      subtitle: 'Help fans find this discovery',
      children: [
        StreamBuilder<List<FandomDoc>>(
          stream: _fandoms(),
          builder: (context, snap) {
            final fandoms = snap.data ?? const <FandomDoc>[];
            if (snap.hasError) {
              return const _InlineHint(
                'Fandoms could not be loaded. Deploy the updated security rules.',
              );
            }
            if (!snap.hasData) {
              return const _FieldSkeleton(label: 'Fandom *');
            }
            final hasCurrent = fandoms.any((f) => f.id == widget.fandomId);
            return _DropdownField(
              key: ValueKey('fandom-${widget.fandomId}-${fandoms.length}'),
              label: 'Fandom *',
              value: hasCurrent ? widget.fandomId : null,
              hint: fandoms.isEmpty
                  ? 'No fandoms yet — add one in Categories'
                  : 'Select a fandom',
              items: [
                for (final f in fandoms)
                  DropdownMenuItem(value: f.id, child: Text(f.name)),
              ],
              onChanged: (id) {
                final f = fandoms.firstWhere((e) => e.id == id);
                widget.onFandomChanged(f.id, f.name);
              },
            );
          },
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<ContentCategoryDoc>>(
          stream: _categories(),
          builder: (context, snap) {
            final categories = snap.data ?? const <ContentCategoryDoc>[];
            if (!snap.hasData) {
              return const _FieldSkeleton(label: 'Category *');
            }
            final hasCurrent = categories.any((c) => c.id == widget.categoryId);
            return _DropdownField(
              key: ValueKey(
                'category-${widget.categoryId}-${categories.length}',
              ),
              label: 'Category *',
              value: hasCurrent ? widget.categoryId : null,
              hint: 'Select a category',
              items: [
                for (final c in categories)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (id) {
                final c = categories.firstWhere((e) => e.id == id);
                widget.onCategoryChanged(c.id, c.name);
              },
            );
          },
        ),
        const SizedBox(height: 16),
        const _FieldLabel('TAGS'),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.tagInput,
                style: const TextStyle(color: Colors.white, fontSize: 14.5),
                cursorColor: AppColors.accent,
                textInputAction: TextInputAction.done,
                onSubmitted: widget.onAddTag,
                decoration: _decoration('Add a tag and press enter'),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => widget.onAddTag(widget.tagInput.text),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.55),
                  ),
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
        if (widget.tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in widget.tags)
                Chip(
                  label: Text('#$tag'),
                  labelStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                  deleteIcon: const Icon(
                    Icons.close_rounded,
                    size: 15,
                    color: Colors.white54,
                  ),
                  onDeleted: () => widget.onRemoveTag(tag),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/* ------------------------------- Section C ------------------------------- */

class _SectionMedia extends StatefulWidget {
  const _SectionMedia({
    required this.coverUrl,
    required this.uploading,
    required this.onPick,
    required this.onRemove,
    required this.onUrlSubmitted,
    required this.videoUrl,
  });

  final String? coverUrl;
  final bool uploading;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final ValueChanged<String> onUrlSubmitted;
  final TextEditingController videoUrl;

  @override
  State<_SectionMedia> createState() => _SectionMediaState();
}

class _SectionMediaState extends State<_SectionMedia> {
  final TextEditingController _url = TextEditingController();

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  /// Fallback for when the image host blocks the upload: paste a link.
  void _applyUrl() {
    final value = _url.text.trim();
    if (value.isEmpty) return;
    widget.onUrlSubmitted(
      value.startsWith('http://') || value.startsWith('https://')
          ? value
          : 'https://$value',
    );
    _url.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final coverUrl = widget.coverUrl;
    final hasCover = coverUrl != null && coverUrl.isNotEmpty;
    return _Section(
      title: 'Media',
      subtitle: 'Cover image shown across the app',
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: hasCover
                ? CachedImage(url: coverUrl, fit: BoxFit.cover)
                : widget.uploading
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : _coverPlaceholder('No cover image yet'),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: GlassButton(
                label: hasCover ? 'Replace image' : 'Select / upload image',
                variant: GlassButtonVariant.outline,
                height: 50,
                isLoading: widget.uploading,
                icon: Icons.image_outlined,
                onPressed: widget.onPick,
              ),
            ),
            if (hasCover) ...[
              const SizedBox(width: 12),
              GestureDetector(
                onTap: widget.onRemove,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.white60,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Upload not working? Paste a direct image link instead.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.42),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _url,
                style: const TextStyle(color: Colors.white, fontSize: 14.5),
                cursorColor: AppColors.accent,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _applyUrl(),
                decoration: _decoration('https://example.com/cover.jpg'),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _applyUrl,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                child: const Icon(Icons.link_rounded, color: Colors.white70),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _EditorField(
          controller: widget.videoUrl,
          label: 'Video URL',
          hint: 'https://example.com/clips/highlight.mp4',
          keyboardType: TextInputType.url,
          validator: _videoUrlValidator,
        ),
        const SizedBox(height: 8),
        Text(
          'Optional — a muted clip plays above the article text. Clear it to remove.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.42),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _coverPlaceholder(String label) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF231018), Color(0xFF14141D)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_outlined,
              color: Colors.white.withValues(alpha: 0.35),
              size: 30,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------------- Section D ------------------------------- */

class _SectionD extends StatelessWidget {
  const _SectionD({
    required this.status,
    required this.isFeatured,
    required this.isTrending,
    required this.onStatusChanged,
    required this.onFeaturedChanged,
    required this.onTrendingChanged,
  });

  final ContentStatus status;
  final bool isFeatured;
  final bool isTrending;
  final ValueChanged<ContentStatus> onStatusChanged;
  final ValueChanged<bool> onFeaturedChanged;
  final ValueChanged<bool> onTrendingChanged;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Publishing',
      subtitle: 'Control visibility and curation',
      children: [
        const _FieldLabel('STATUS'),
        Row(
          children: [
            for (final s in ContentStatus.values) ...[
              Expanded(
                child: GestureDetector(
                  onTap: () => onStatusChanged(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: status == s
                          ? LinearGradient(
                              colors: s.isPublished
                                  ? const [Color(0xFF10B981), Color(0xFF047857)]
                                  : const [
                                      Color(0xFFF59E0B),
                                      Color(0xFFB45309),
                                    ],
                            )
                          : null,
                      color: status == s
                          ? null
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: status == s ? 0.28 : 0.1,
                        ),
                      ),
                    ),
                    child: Text(
                      s.label,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight:
                            status == s ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              if (s != ContentStatus.values.last) const SizedBox(width: 10),
            ],
          ],
        ),
        const SizedBox(height: 18),
        _ToggleRow(
          icon: Icons.star_rounded,
          iconColor: const Color(0xFFF59E0B),
          label: 'Featured',
          subtitle: 'Show in the Featured spotlight on Fan Home',
          value: isFeatured,
          onChanged: onFeaturedChanged,
        ),
        const SizedBox(height: 10),
        _ToggleRow(
          icon: Icons.trending_up_rounded,
          iconColor: const Color(0xFF10B981),
          label: 'Trending',
          subtitle: 'Surface under Trending Now',
          value: isTrending,
          onChanged: onTrendingChanged,
        ),
      ],
    );
  }
}

/* -------------------------------- Building ------------------------------- */

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

InputDecoration _decoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13.5),
    filled: true,
    fillColor: const Color(0x59000000),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.accent, width: 1.6),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.6),
    ),
  );
}

/// Optional field: empty is valid, anything else must be an http(s) link.
String? _videoUrlValidator(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  final valid = uri != null &&
      (uri.isScheme('http') || uri.isScheme('https')) &&
      uri.host.isNotEmpty;
  return valid ? null : 'Enter a full link starting with https://';
}

class _EditorField extends StatelessWidget {
  const _EditorField({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.validator,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        height: 1.5,
        fontWeight: FontWeight.w500,
      ),
      cursorColor: AppColors.accent,
      decoration: _decoration(hint ?? label).copyWith(
        labelText: label,
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: const TextStyle(
          color: AppColors.accent,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final String hint;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      dropdownColor: const Color(0xF2101018),
      style: const TextStyle(color: Colors.white, fontSize: 14.5),
      hint: Text(
        hint,
        style: const TextStyle(color: Colors.white38, fontSize: 13.5),
      ),
      decoration: _decoration(hint).copyWith(labelText: label),
      items: items,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _FieldSkeleton extends StatelessWidget {
  const _FieldSkeleton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label.toUpperCase()),
        Container(
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
      ],
    );
  }
}

class _InlineHint extends StatelessWidget {
  const _InlineHint(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B6B).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFF6B6B).withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFFFFAFAF), fontSize: 12.5, height: 1.4),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final ContentType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFFE50914), Color(0xFF8E0910)],
                )
              : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: selected ? 0.28 : 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              type.icon,
              size: 15,
              color: selected ? Colors.white : Colors.white70,
            ),
            const SizedBox(width: 7),
            Text(
              type.label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value
              ? iconColor.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
