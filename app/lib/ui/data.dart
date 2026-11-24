import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/obj.dart';
import '../core/theme.dart';
import 'kit.dart';

/// Loads one API answer, with skeleton, error + retry and pull to refresh.
class Loader extends StatefulWidget {
  const Loader({super.key, required this.load, required this.builder, this.skeletonRows = 6, this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 32)});
  final Future<Obj> Function() load;
  final Widget Function(BuildContext, Obj, Future<void> Function() reload) builder;
  final int skeletonRows;
  final EdgeInsets padding;
  @override
  State<Loader> createState() => LoaderState();
}

class LoaderState extends State<Loader> {
  Obj? data;
  String? error;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final d = await widget.load();
      if (mounted) {
        setState(() {
          data = d;
          error = null;
        });
      }
    } on ApiError catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (data == null && error == null) return ListView(padding: widget.padding, children: [Skeleton(rows: widget.skeletonRows)]);
    if (data == null) return ListView(padding: widget.padding, children: [ErrorState(error!, onRetry: () {
          setState(() => error = null);
          reload();
        })]);
    return RefreshIndicator(
      color: context.ci.brand,
      backgroundColor: context.ci.surface,
      onRefresh: reload,
      child: _scrollable(widget.builder(context, data!, reload)),
    );
  }

  /// Screens may return a plain Column: give it the page padding and pull-to-refresh scrolling.
  Widget _scrollable(Widget child) {
    if (child is ScrollView) return child;
    return ListView(padding: widget.padding, physics: const AlwaysScrollableScrollPhysics(), children: [child]);
  }
}

/// A paged list from an endpoint that answers { data: [...], meta: {current_page, last_page} }.
class PagedList extends StatefulWidget {
  const PagedList({super.key, required this.path, required this.item, this.query = const {}, this.empty = 'مفيش حاجة هنا', this.emptyIcon = 'check', this.header, this.search = true, this.searchHint = 'دوّر...', this.separator = 10});
  final String path;
  final Map<String, dynamic> query;
  final Widget Function(BuildContext, Obj) item;
  final String empty, emptyIcon, searchHint;
  final Widget? header;
  final bool search;
  final double separator;
  @override
  State<PagedList> createState() => PagedListState();
}

class PagedListState extends State<PagedList> {
  final items = <Obj>[];
  int page = 0, last = 1, total = 0;
  bool loading = false;
  String? error;
  String q = '';
  Timer? _deb;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    refresh();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) more();
    });
  }

  @override
  void didUpdateWidget(PagedList old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path || old.query.toString() != widget.query.toString()) refresh();
  }

  @override
  void dispose() {
    _deb?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    page = 0;
    last = 1;
    items.clear();
    error = null;
    await more(force: true);
  }

  Future<void> more({bool force = false}) async {
    if (loading || (!force && page >= last)) return;
    setState(() => loading = true);
    try {
      final r = await Api.I.get(widget.path, {...widget.query, 'page': page + 1, if (q.isNotEmpty) 'q': q});
      final meta = r.o('meta');
      if (!mounted) return;
      setState(() {
        items.addAll(r.l('data'));
        page = meta.i('current_page', page + 1);
        last = meta.i('last_page', page);
        total = meta.i('total', items.length);
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      if (widget.search)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: CommandField(hint: widget.searchHint, onChanged: (v) {
            _deb?.cancel();
            _deb = Timer(const Duration(milliseconds: 350), () {
              q = v.trim();
              refresh();
            });
          }),
        ),
      if (widget.header != null) widget.header!,
    ];
    Widget body;
    if (items.isEmpty && loading) {
      body = const Skeleton(rows: 5);
    } else if (items.isEmpty && error != null) {
      body = ErrorState(error!, onRetry: refresh);
    } else if (items.isEmpty) {
      body = EmptyState(q.isEmpty ? widget.empty : 'مفيش نتايج لـ "$q"', icon: q.isEmpty ? widget.emptyIcon : 'search');
    } else {
      body = const SizedBox.shrink();
    }
    return RefreshIndicator(
      color: context.ci.brand,
      backgroundColor: context.ci.surface,
      onRefresh: refresh,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: children.length + 1 + items.length + (loading && items.isNotEmpty ? 1 : 0),
        separatorBuilder: (_, i) => SizedBox(height: i < children.length ? 0 : widget.separator),
        itemBuilder: (c, i) {
          if (i < children.length) return children[i];
          if (i == children.length) return items.isEmpty ? body : const SizedBox.shrink();
          final k = i - children.length - 1;
          if (k >= items.length) return const Padding(padding: EdgeInsets.all(16), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))));
          return widget.item(c, items[k]);
        },
      ),
    );
  }
}

/// The brand's command-bar search: "> " prompt and a blinking caret when empty.
class CommandField extends StatefulWidget {
  const CommandField({super.key, this.hint = 'دوّر...', this.onChanged, this.onSubmitted, this.autofocus = false, this.controller});
  final String hint;
  final ValueChanged<String>? onChanged, onSubmitted;
  final bool autofocus;
  final TextEditingController? controller;
  @override
  State<CommandField> createState() => _CommandFieldState();
}

class _CommandFieldState extends State<CommandField> {
  late final c = widget.controller ?? TextEditingController();
  final focus = FocusNode();
  @override
  void initState() {
    super.initState();
    c.addListener(() => setState(() {}));
    focus.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final active = focus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: context.ci.sunken,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: active ? context.ci.brand : context.ci.line, width: active ? 1.4 : 1),
      ),
      child: Row(children: [
        Text('>', style: mono(context, size: 15, color: context.ci.brand, w: FontWeight.w600)),
        const SizedBox(width: 10),
        Expanded(
          child: Stack(alignment: AlignmentDirectional.centerStart, children: [
            if (c.text.isEmpty && !active) Row(children: [Text(widget.hint, style: context.tt.bodyMedium!.copyWith(color: context.ci.subtle)), const SizedBox(width: 4), const Caret(height: 15, width: 7)]),
            TextField(
              controller: c,
              focusNode: focus,
              autofocus: widget.autofocus,
              textInputAction: TextInputAction.search,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              style: context.tt.bodyMedium,
              cursorColor: context.ci.brand,
              cursorWidth: 7,
              decoration: const InputDecoration(filled: false, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
            ),
          ]),
        ),
        if (c.text.isNotEmpty)
          GestureDetector(onTap: () {
            c.clear();
            widget.onChanged?.call('');
          }, child: Icon(Icons.close_rounded, size: 18, color: context.ci.subtle)),
      ]),
    );
  }
}

/// Page with the brand header: mono eyebrow over a big title.
class CiPage extends StatelessWidget {
  const CiPage({super.key, required this.title, this.eyebrow, required this.body, this.actions = const [], this.fab, this.bottom, this.back = true});
  final String title;
  final String? eyebrow;
  final Widget body;
  final List<Widget> actions;
  final Widget? fab;
  final PreferredSizeWidget? bottom;
  final bool back;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: back,
          toolbarHeight: eyebrow == null ? 60 : 70,
          titleSpacing: back ? 0 : 20,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (eyebrow != null) ...[Eyebrow(eyebrow!), const SizedBox(height: 4)],
            Text(title, style: context.tt.titleLarge!.copyWith(fontSize: 19), overflow: TextOverflow.ellipsis),
          ]),
          actions: [...actions, const SizedBox(width: 8)],
          bottom: bottom,
          shape: Border(bottom: BorderSide(color: context.ci.line)),
        ),
        floatingActionButton: fab,
        body: SafeArea(top: false, child: body),
      );
}
