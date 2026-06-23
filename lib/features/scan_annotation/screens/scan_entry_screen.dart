import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/responsive.dart';

/// 스캔 첨삭 진입 화면.
///
/// 두 경로를 제공합니다(기술기획서 7 "스캔 → 주석"):
///  1) 문서 스캔: cunning_document_scanner (실기기, 테두리 감지/원근 보정)
///  2) 갤러리에서 선택: image_picker (이미 찍어둔 이미지)
/// 선택된 이미지를 주석 에디터로 넘깁니다.
class ScanEntryScreen extends StatefulWidget {
  const ScanEntryScreen({super.key, required this.authorRole, this.roomId});
  final String authorRole; // 'student' | 'mentor'
  final String? roomId; // 방 맥락(저장 대상). null = 데모(저장 안 함)

  @override
  State<ScanEntryScreen> createState() => _ScanEntryScreenState();
}

class _ScanEntryScreenState extends State<ScanEntryScreen> {
  bool _busy = false;

  Future<void> _openEditor(String path) async {
    if (!mounted) return;
    context.push('/annotate', extra: {
      'path': path,
      'role': widget.authorRole,
      'roomId': widget.roomId,
    });
  }

  Future<void> _scanDocument() async {
    setState(() => _busy = true);
    try {
      // cunning_document_scanner는 실기기에서만 동작. 동적 호출로 감싸
      // 미지원 환경(에뮬레이터/데스크톱)에선 갤러리로 안내.
      final paths = await _tryNativeScan();
      if (paths != null && paths.isNotEmpty) {
        await _openEditor(paths.first);
      } else {
        _hint('이 환경에서는 스캔이 지원되지 않아요. 갤러리에서 선택해 주세요.');
      }
    } catch (_) {
      _hint('스캔을 시작할 수 없어요. 갤러리에서 선택해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // 문서 스캔(테두리 감지/원근 보정). 실기기에서만 동작하며, 미지원/취소 시
  // null 을 반환해 갤러리 선택으로 폴백합니다.
  Future<List<String>?> _tryNativeScan() async {
    return CunningDocumentScanner.getPictures();
  }

  Future<void> _pickFromGallery() async {
    setState(() => _busy = true);
    try {
      final picker = ImagePicker();
      final XFile? file =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
      if (file != null) {
        await _openEditor(file.path);
      }
    } catch (_) {
      _hint('이미지를 불러오지 못했어요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _hint(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('문서 스캔 & 첨삭')),
      body: ContentContainer(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              _OptionCard(
                icon: Icons.document_scanner,
                title: '문서 스캔',
                subtitle: '카메라로 문제지·노트를 스캔합니다',
                color: AppColors.primary,
                onTap: _busy ? null : _scanDocument,
              ),
              const SizedBox(height: 14),
              _OptionCard(
                icon: Icons.photo_library_outlined,
                title: '갤러리에서 선택',
                subtitle: '이미 찍어둔 이미지를 불러옵니다',
                color: AppColors.mentorAccent,
                onTap: _busy ? null : _pickFromGallery,
              ),
              const Spacer(),
              if (_busy) const Center(child: CircularProgressIndicator()),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '스캔 원본은 배경(편집 불가) 레이어가 되고, 펜 첨삭은 그 위 주석\n'
                  '레이어로 저장됩니다. 좌표는 이미지 기준 0~1로 보관되어 어떤\n'
                  '기기·확대 배율에서도 첨삭 위치가 어긋나지 않아요.',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// 파일 경로 → FileImage 헬퍼 (라우터가 주석 에디터에 넘길 ImageProvider 생성).
ImageProvider scanImageFromPath(String path) => FileImage(File(path));
