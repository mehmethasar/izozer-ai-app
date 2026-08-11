import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mazdek_ai/core/services/document_scanner_service.dart';
import 'package:mazdek_ai/core/services/speech_service.dart';
import 'package:mazdek_ai/app/app_scope.dart';
import 'package:mazdek_ai/models/models.dart';
import 'package:mazdek_ai/widgets/common.dart';
import 'package:share_plus/share_plus.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatLine {
  const _ChatLine({required this.text, required this.user, this.action, this.artifacts = const []});
  final String text;
  final bool user;
  final PendingAction? action;
  final List<ChatArtifact> artifacts;
}

class _ChatScreenState extends State<ChatScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  final speech = SpeechService();
  final scanner = DocumentScannerService();
  List<_ChatLine> lines = const [];
  bool loading = true, sending = false, listening = false;
  String? error;
  bool draftLoaded = false;

  @override void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => load()); }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (draftLoaded) return;
    draftLoaded = true;
    final draft = AppScope.of(context).consumeChatDraft();
    if (draft != null && draft.isNotEmpty) {
      input.text = draft;
      input.selection = TextSelection.collapsed(offset: input.text.length);
    }
  }
  @override
  void dispose() {
    unawaited(speech.cancel());
    unawaited(scanner.clearTemporaryFiles());
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final history = await AppScope.of(context).api.chatHistory();
      if (!mounted) return;
      setState(() => lines = history.expand((e) => [_ChatLine(text: e.message, user: true), _ChatLine(text: e.reply, user: false, artifacts: e.artifacts)]).toList());
    } catch (e) { if (mounted) setState(() => error = e.toString()); }
    finally { if (mounted) { setState(() => loading = false); _bottom(); } }
  }

  Future<void> send() async {
    final message = input.text.trim();
    if (message.isEmpty || sending) return;
    input.clear();
    setState(() { sending = true; error = null; lines = [...lines, _ChatLine(text: message, user: true)]; });
    _bottom();
    try {
      final response = await AppScope.of(context).api.chat(message);
      if (!mounted) return;
      setState(() => lines = [...lines, _ChatLine(text: response.reply, user: false, action: response.action, artifacts: response.artifacts)]);
    } catch (e) { if (mounted) setState(() => error = e.toString()); }
    finally { if (mounted) { setState(() => sending = false); _bottom(); } }
  }

  Future<void> attach() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf','jpg','jpeg','png','heic','heif']);
    final path = result?.files.single.path;
    if (path == null) return;
    await uploadFile(File(path), result!.files.single.name);
  }

  Future<void> scanDocument() async {
    try {
      final file = await scanner.scanPdf();
      if (file == null) return;
      await uploadFile(file, 'taranan-belge.pdf');
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> uploadFile(File file, String name) async {
    final message = input.text.trim().isEmpty ? 'Bu belgeyi analiz et ve uygun takip kaydı taslağı hazırla.' : input.text.trim();
    input.clear();
    setState(() { sending = true; error = null; lines = [...lines, _ChatLine(text: '📎 $name\n$message', user: true)]; });
    _bottom();
    try {
      final response = await AppScope.of(context).api.uploadAttachment(file: file, message: message);
      if (!mounted) return;
      setState(() => lines = [...lines, _ChatLine(text: response.reply, user: false, action: response.action, artifacts: response.artifacts)]);
    } catch (e) { if (mounted) setState(() => error = e.toString()); }
    finally { if (mounted) { setState(() => sending = false); _bottom(); } }
  }

  Future<void> toggleVoice() async {
    if (listening) {
      await speech.stop();
      if (mounted) setState(() => listening = false);
      return;
    }
    final available = await speech.start(onText: (text, finalResult) {
      if (!mounted) return;
      setState(() {
        input.text = text;
        input.selection = TextSelection.collapsed(offset: input.text.length);
        if (finalResult) listening = false;
      });
    });
    if (!mounted) return;
    setState(() {
      listening = available;
      if (!available) error = 'Bu cihazda Türkçe sesli komut kullanılamıyor veya mikrofon izni verilmedi.';
    });
  }

  Future<void> confirm(PendingAction action) async {
    setState(() => sending = true);
    try {
      final result = await AppScope.of(context).api.confirm(action.id);
      final message = result['message']?.toString() ?? 'İşlem uygulandı.';
      if (mounted) setState(() => lines = [...lines, _ChatLine(text: '✅ $message', user: false)]);
    } catch (e) { if (mounted) setState(() => error = e.toString()); }
    finally { if (mounted) setState(() => sending = false); }
  }

  Future<void> cancel(PendingAction action) async {
    setState(() => sending = true);
    try { await AppScope.of(context).api.cancel(action.id); if (mounted) setState(() => lines = [...lines, const _ChatLine(text: 'İşlem taslağı iptal edildi.', user: false)]); }
    catch (e) { if (mounted) setState(() => error = e.toString()); }
    finally { if (mounted) setState(() => sending = false); }
  }

  Future<void> shareArtifact(ChatArtifact artifact) async {
    try {
      final file = await AppScope.of(context).api.download(artifact.path, artifact.name);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: artifact.name));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }

  void _bottom() { WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted && scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut); }); }

  @override Widget build(BuildContext context) {
    if (loading) return const LoadingPane();
    return Column(children: [
      if (error != null) Padding(padding: const EdgeInsets.fromLTRB(12, 6, 12, 0), child: StatusBanner(text: error!, icon: Icons.error_outline, warning: true)),
      Expanded(child: lines.isEmpty ? const EmptyState(title: 'Mazdek hazır', message: '“Bugünkü gelir ve giderleri özetle” veya “Shell projesine 12.500 TL vinç gideri ekle” diye yazabilirsiniz.', icon: Icons.auto_awesome) : ListView.builder(controller: scroll, padding: const EdgeInsets.fromLTRB(12, 12, 12, 20), itemCount: lines.length, itemBuilder: (context, index) => _MessageBubble(line: lines[index], busy: sending, onConfirm: confirm, onCancel: cancel, onArtifact: shareArtifact))),
      if (sending) const LinearProgressIndicator(minHeight: 2),
      SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(10, 8, 10, 10), child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        IconButton.filledTonal(onPressed: sending ? null : scanDocument, icon: const Icon(Icons.document_scanner_outlined), tooltip: 'Çok sayfalı belge tara'), const SizedBox(width: 6),
        IconButton.filledTonal(onPressed: sending ? null : attach, icon: const Icon(Icons.attach_file), tooltip: 'Dosya ekle'), const SizedBox(width: 6),
        Expanded(child: TextField(controller: input, minLines: 1, maxLines: 5, textInputAction: TextInputAction.newline, decoration: InputDecoration(hintText: listening ? 'Dinleniyor…' : 'Şirketinizle ilgili sorun veya işlem yazın…'))), const SizedBox(width: 6),
        IconButton.filledTonal(onPressed: sending ? null : toggleVoice, icon: Icon(listening ? Icons.stop_circle_outlined : Icons.mic_none), tooltip: listening ? 'Dinlemeyi durdur' : 'Sesli komut'), const SizedBox(width: 6),
        IconButton.filled(onPressed: sending ? null : send, icon: const Icon(Icons.arrow_upward), tooltip: 'Gönder'),
      ]))),
    ]);
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.line,
    required this.busy,
    required this.onConfirm,
    required this.onCancel,
    required this.onArtifact,
  });

  final _ChatLine line;
  final bool busy;
  final ValueChanged<PendingAction> onConfirm;
  final ValueChanged<PendingAction> onCancel;
  final ValueChanged<ChatArtifact> onArtifact;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: line.user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: line.user
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(line.text),
            if (line.action != null) ...[
              const SizedBox(height: 12),
              _ActionCard(
                action: line.action!,
                busy: busy,
                onConfirm: onConfirm,
                onCancel: onCancel,
              ),
            ],
            if (line.artifacts.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...line.artifacts.map(
                (artifact) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: OutlinedButton.icon(
                    onPressed: () => onArtifact(artifact),
                    icon: const Icon(Icons.download_outlined),
                    label: Text(artifact.name, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.action,
    required this.busy,
    required this.onConfirm,
    required this.onCancel,
  });

  final PendingAction action;
  final bool busy;
  final ValueChanged<PendingAction> onConfirm;
  final ValueChanged<PendingAction> onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(action.title, style: const TextStyle(fontWeight: FontWeight.w800)),
          if (action.primaryName != null)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text(action.primaryName!)),
          if (action.summary.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text(action.summary)),
          if (action.amount != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                money(action.amount!),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : () => onCancel(action),
                  child: const Text('İptal'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : () => onConfirm(action),
                  child: const Text('Onayla ve Uygula'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
