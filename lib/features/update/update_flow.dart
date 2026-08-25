import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/fa_number.dart';
import '../../services/update_service.dart';

final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService());

/// One check per app session (used by the auto-check on startup).
final updateCheckProvider = FutureProvider<UpdateCheckResult>((ref) async {
  final svc = ref.watch(updateServiceProvider);
  return svc.check();
});

/// Runs the guided update flow: check → confirm → download → installer.
Future<void> runUpdateFlow(
  BuildContext context,
  WidgetRef ref, {
  UpdateCheckResult? precheck,
}) async {
  final svc = ref.read(updateServiceProvider);
  final messenger = ScaffoldMessenger.of(context);

  // 1) Check latest GitHub release (reuse precheck when provided).
  final result = precheck ?? await svc.check();
  if (!context.mounted) return;

  if (!result.hasUpdate) {
    messenger.showSnackBar(
      const SnackBar(content: Text('شما جدیدترین نسخه را دارید ✅')),
    );
    return;
  }

  // 2) Confirm.
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('بروزرسانی موجود است'),
      content: Text(
        'نسخه ${result.latestVersion!.replaceFirst('v', '').faString} در دسترس است.\n'
        'نسخه فعلی شما: ${result.currentVersion.faString}\n\n'
        'دانلود و نصب انجام شود؟',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('بعداً'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('دانلود و نصب'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  // 3) Download with live progress.
  final progress = ValueNotifier<double>(0);
  String? apkPath;
  String? error;
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _DownloadDialog(
      progress: progress,
      start: () async {
        try {
          apkPath = await svc.downloadApk(
            result.apkUrl!,
            onProgress: (r, t) {
              progress.value = t > 0 ? r / t : 0;
            },
          );
          return true;
        } on DioException catch (e) {
          error = e.type == DioExceptionType.cancel
              ? 'لغو شد'
              : 'خطا در دانلود — اتصال را بررسی کنید';
          return false;
        } catch (_) {
          error = 'خطا در دانلود — اتصال را بررسی کنید';
          return false;
        }
      }(),
    ),
  );
  progress.dispose();
  if (!context.mounted) return;
  if (ok != true) {
    if (error != null && error != 'لغو شد') {
      messenger.showSnackBar(SnackBar(content: Text(error!)));
    }
    return;
  }
  if (apkPath == null) return;

  // 4) Hand off to the Android package installer.
  final started = await svc.install(apkPath!);
  if (!started) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'اجازه نصب از منابع ناشناس داده نشده — از تنظیمات اندروید فعال کنید',
        ),
      ),
    );
  }
}

class _DownloadDialog extends StatefulWidget {
  const _DownloadDialog({required this.progress, required this.start});

  final ValueNotifier<double> progress;
  final Future<bool> start;

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    widget.start.then((ok) {
      _done = true;
      if (mounted) Navigator.of(context).pop(ok);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _done,
      child: AlertDialog(
        title: const Text('در حال دانلود بروزرسانی...'),
        content: ValueListenableBuilder<double>(
          valueListenable: widget.progress,
          builder: (_, v, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: v <= 0 ? null : v),
              const SizedBox(height: 8),
              Text('${(v * 100).toStringAsFixed(0)}٪'.faString),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('لغو'),
          ),
        ],
      ),
    );
  }
}
