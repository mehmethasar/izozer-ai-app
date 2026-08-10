import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mazdek_ai/app/app_scope.dart';
import 'package:mazdek_ai/widgets/common.dart';

class IntegrationSettingsScreen extends StatefulWidget {
  const IntegrationSettingsScreen({super.key});
  @override State<IntegrationSettingsScreen> createState() => _IntegrationSettingsScreenState();
}

class _IntegrationSettingsScreenState extends State<IntegrationSettingsScreen> {
  final openaiKey = TextEditingController();
  final openaiModel = TextEditingController(text: 'gpt-5-mini');
  final visionModel = TextEditingController(text: 'gpt-5-mini');
  final openaiBase = TextEditingController(text: 'https://api.openai.com/v1');
  final kolaybiKey = TextEditingController();
  final kolaybiChannel = TextEditingController();
  final kolaybiBase = TextEditingController(text: 'https://ofis-sandbox-api.kolaybi.com/kolaybi/v1');
  final gatewayId = TextEditingController();
  final appleBundleId = TextEditingController();
  final appleServiceId = TextEditingController();
  final appleRedirectUri = TextEditingController();
  final appleTeamId = TextEditingController();
  final appleKeyId = TextEditingController();
  final apnsTeamId = TextEditingController();
  final apnsKeyId = TextEditingController();
  final apnsBundleId = TextEditingController();
  final fcmProjectId = TextEditingController();
  String? applePrivateKey, apnsPrivateKey, fcmServiceAccount;
  bool syncWrites = false, storeResponses = false, busy = true;
  String apnsEnvironment = 'sandbox';
  String? message;
  Map<String, dynamic>? status;

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => load()); }

  @override
  void dispose() {
    for (final controller in [openaiKey, openaiModel, visionModel, openaiBase, kolaybiKey, kolaybiChannel, kolaybiBase, gatewayId, appleBundleId, appleServiceId, appleRedirectUri, appleTeamId, appleKeyId, apnsTeamId, apnsKeyId, apnsBundleId, fcmProjectId]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final result = await AppScope.of(context).api.integrationStatus();
      final openai = result['openai'] as Map<String, dynamic>? ?? {};
      final kolaybi = result['kolaybi'] as Map<String, dynamic>? ?? {};
      final apple = result['apple'] as Map<String, dynamic>? ?? {};
      final apns = result['apns'] as Map<String, dynamic>? ?? {};
      final fcm = result['fcm'] as Map<String, dynamic>? ?? {};
      openaiModel.text = '${openai['model'] ?? 'gpt-5-mini'}';
      visionModel.text = '${openai['visionModel'] ?? openaiModel.text}';
      openaiBase.text = '${openai['baseUrl'] ?? 'https://api.openai.com/v1'}';
      storeResponses = openai['storeResponses'] == true;
      kolaybiChannel.text = '${kolaybi['channel'] ?? ''}';
      kolaybiBase.text = '${kolaybi['baseUrl'] ?? 'https://ofis-sandbox-api.kolaybi.com/kolaybi/v1'}';
      gatewayId.text = '${kolaybi['gatewayId'] ?? ''}';
      syncWrites = kolaybi['syncWrites'] == true;
      appleBundleId.text = '${apple['bundleId'] ?? apple['clientId'] ?? ''}';
      appleServiceId.text = '${apple['serviceId'] ?? ''}';
      appleRedirectUri.text = '${apple['redirectUri'] ?? ''}';
      appleTeamId.text = '${apple['teamId'] ?? ''}';
      appleKeyId.text = '${apple['keyId'] ?? ''}';
      apnsTeamId.text = '${apns['teamId'] ?? ''}';
      apnsKeyId.text = '${apns['keyId'] ?? ''}';
      apnsBundleId.text = '${apns['bundleId'] ?? ''}';
      apnsEnvironment = '${apns['environment'] ?? 'sandbox'}';
      fcmProjectId.text = '${fcm['projectId'] ?? ''}';
      if (mounted) setState(() => status = result);
    } catch (e) { if (mounted) setState(() => message = e.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<String?> pickTextFile(List<String> extensions) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: extensions, withData: true);
    if (result == null) return null;
    final file = result.files.single;
    if (file.bytes != null) return utf8.decode(file.bytes!);
    if (file.path != null) return File(file.path!).readAsString();
    return null;
  }

  Future<void> save() async {
    setState(() { busy = true; message = null; });
    try {
      final values = <String, dynamic>{
        'openaiModel': openaiModel.text.trim(), 'openaiVisionModel': visionModel.text.trim(), 'openaiBaseUrl': openaiBase.text.trim(), 'openaiStoreResponses': storeResponses,
        'kolaybiChannel': kolaybiChannel.text.trim(), 'kolaybiBaseUrl': kolaybiBase.text.trim(), 'kolaybiGatewayId': gatewayId.text.trim(), 'kolaybiGatewayType': 'Vault', 'kolaybiSyncWrites': syncWrites,
        'appleBundleId': appleBundleId.text.trim(), 'appleServiceId': appleServiceId.text.trim(), 'appleRedirectUri': appleRedirectUri.text.trim(), 'appleTeamId': appleTeamId.text.trim(), 'appleKeyId': appleKeyId.text.trim(),
        'apnsTeamId': apnsTeamId.text.trim(), 'apnsKeyId': apnsKeyId.text.trim(), 'apnsBundleId': apnsBundleId.text.trim(), 'apnsEnvironment': apnsEnvironment,
        'fcmProjectId': fcmProjectId.text.trim(),
        if (openaiKey.text.trim().isNotEmpty) 'openaiApiKey': openaiKey.text.trim(),
        if (kolaybiKey.text.trim().isNotEmpty) 'kolaybiApiKey': kolaybiKey.text.trim(),
        if (applePrivateKey != null) 'applePrivateKey': applePrivateKey,
        if (apnsPrivateKey != null) 'apnsPrivateKey': apnsPrivateKey,
        if (fcmServiceAccount != null) 'fcmServiceAccountJson': fcmServiceAccount,
      };
      await AppScope.of(context).api.updateIntegrationSettings(values);
      openaiKey.clear(); kolaybiKey.clear(); applePrivateKey = null; apnsPrivateKey = null; fcmServiceAccount = null;
      await load();
      if (mounted) setState(() => message = 'Entegrasyon ayarları şifreli olarak kaydedildi.');
    } catch (e) { if (mounted) setState(() => message = e.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> test(String kind) async {
    setState(() { busy = true; message = null; });
    try {
      final api = AppScope.of(context).api;
      final result = switch (kind) { 'openai' => await api.testOpenAI(), 'kolaybi' => await api.testKolayBi(), 'apns' => await api.testAPNS(), 'fcm' => await api.testFCM(), _ => await api.testNotification() };
      if (mounted) setState(() => message = '${kind.toUpperCase()} testi başarılı: ${jsonEncode(result)}');
    } catch (e) { if (mounted) setState(() => message = e.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Widget field(TextEditingController controller, String label, {bool secret = false, int maxLines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(controller: controller, obscureText: secret, maxLines: secret ? 1 : maxLines, decoration: InputDecoration(labelText: label)),
  );

  Widget section(String title, IconData icon, List<Widget> children) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Row(children: [Icon(icon), const SizedBox(width: 10), Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))]), const SizedBox(height: 14), ...children])),
  );

  @override
  Widget build(BuildContext context) {
    final openaiConfigured = (status?['openai'] as Map?)?['configured'] == true;
    final kolaybiConfigured = (status?['kolaybi'] as Map?)?['configured'] == true;
    final appleStatus = status?['apple'] as Map?;
    final appleIOSReady = appleStatus?['iosReady'] == true;
    final appleAndroidReady = appleStatus?['androidReady'] == true;
    final apnsConfigured = (status?['apns'] as Map?)?['configured'] == true;
    final fcmConfigured = (status?['fcm'] as Map?)?['configured'] == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Entegrasyon Kurulum Merkezi')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (message != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: StatusBanner(text: message!, warning: message!.toLowerCase().contains('hata'))),
        section('OpenAI', Icons.auto_awesome, [
          Text(openaiConfigured ? 'Bağlı' : 'Yerel yapay zekâ motoru aktif; gelişmiş analiz için anahtar ekleyin.'), const SizedBox(height: 10),
          field(openaiKey, 'Yeni OpenAI API anahtarı', secret: true), field(openaiModel, 'Sohbet modeli'), field(visionModel, 'Belge/görsel modeli'), field(openaiBase, 'OpenAI API adresi'),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: storeResponses, onChanged: (v) => setState(() => storeResponses = v), title: const Text('Yanıtları sağlayıcıda sakla')),
          OutlinedButton(onPressed: busy || !openaiConfigured ? null : () => test('openai'), child: const Text('OpenAI Bağlantısını Test Et')),
        ]),
        section('KolayBi', Icons.sync, [
          Text(kolaybiConfigured ? 'Bağlı' : 'API Key ve Channel girilmedi.'), const SizedBox(height: 10),
          field(kolaybiKey, 'Yeni KolayBi API Key', secret: true), field(kolaybiChannel, 'Channel'), field(kolaybiBase, 'KolayBi API adresi'), field(gatewayId, 'Varsayılan kasa/banka geçit ID'),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: syncWrites, onChanged: (v) => setState(() => syncWrites = v), title: const Text('Onaylı tahsilat/ödeme yazma'), subtitle: const Text('Yalnızca sandbox doğrulamasından sonra açın.')),
          OutlinedButton(onPressed: busy || !kolaybiConfigured ? null : () => test('kolaybi'), child: const Text('KolayBi Bağlantısını Test Et')),
        ]),
        section('Apple ile Giriş ve iOS APNs', Icons.apple, [
          const Text('iOS doğal Apple girişi App ID ile, Android web akışı ise ayrı Service ID ile doğrulanır.'), const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            Chip(avatar: Icon(appleIOSReady ? Icons.check_circle : Icons.error_outline, size: 18), label: Text(appleIOSReady ? 'iOS Apple hazır' : 'iOS Apple eksik')),
            Chip(avatar: Icon(appleAndroidReady ? Icons.check_circle : Icons.error_outline, size: 18), label: Text(appleAndroidReady ? 'Android Apple hazır' : 'Android Apple eksik')),
          ]), const SizedBox(height: 10),
          field(appleBundleId, 'iOS Apple App ID / Bundle ID'), field(appleServiceId, 'Android Apple Service ID'), field(appleRedirectUri, 'Android Apple dönüş adresi (HTTPS)'), field(appleTeamId, 'Apple Team ID'), field(appleKeyId, 'Apple Sign in Key ID'),
          OutlinedButton.icon(onPressed: busy ? null : () async { final value = await pickTextFile(const ['p8']); if (value != null) setState(() => applePrivateKey = value); }, icon: const Icon(Icons.key), label: Text(applePrivateKey == null ? 'Apple Sign in .p8 Seç' : 'Apple Sign in .p8 Seçildi')),
          const Divider(height: 28), field(apnsTeamId, 'APNs Team ID'), field(apnsKeyId, 'APNs Key ID'), field(apnsBundleId, 'iOS Bundle ID'),
          DropdownButtonFormField<String>(initialValue: apnsEnvironment, decoration: const InputDecoration(labelText: 'APNs ortamı'), items: const [DropdownMenuItem(value: 'sandbox', child: Text('Sandbox')), DropdownMenuItem(value: 'production', child: Text('Production'))], onChanged: (v) => setState(() => apnsEnvironment = v ?? 'sandbox')),
          const SizedBox(height: 10), OutlinedButton.icon(onPressed: busy ? null : () async { final value = await pickTextFile(const ['p8']); if (value != null) setState(() => apnsPrivateKey = value); }, icon: const Icon(Icons.notifications), label: Text(apnsPrivateKey == null ? 'APNs .p8 Seç' : 'APNs .p8 Seçildi')),
          OutlinedButton(onPressed: busy || !apnsConfigured ? null : () => test('apns'), child: const Text('APNs Yapılandırmasını Test Et')),
        ]),
        section('Android / Firebase Cloud Messaging', Icons.android, [
          Text(fcmConfigured ? 'FCM bağlı' : 'Google Play uzaktan bildirimleri için Firebase servis hesabı ekleyin.'), const SizedBox(height: 10),
          field(fcmProjectId, 'Firebase Project ID'),
          OutlinedButton.icon(onPressed: busy ? null : () async { final value = await pickTextFile(const ['json']); if (value != null) setState(() => fcmServiceAccount = value); }, icon: const Icon(Icons.upload_file), label: Text(fcmServiceAccount == null ? 'Firebase Servis Hesabı JSON Seç' : 'Firebase JSON Seçildi')),
          OutlinedButton(onPressed: busy || !fcmConfigured ? null : () => test('fcm'), child: const Text('FCM Bağlantısını Test Et')),
          FilledButton.tonal(onPressed: busy || (!fcmConfigured && !apnsConfigured) ? null : () => test('notification'), child: const Text('Bu Cihaza Test Bildirimi Gönder')),
        ]),
        FilledButton.icon(onPressed: busy ? null : save, icon: const Icon(Icons.save), label: const Text('Tüm Ayarları Güvenli Kaydet')),
        if (busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
      ]),
    );
  }
}
