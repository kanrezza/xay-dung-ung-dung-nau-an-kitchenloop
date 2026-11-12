import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../data/recipe_exceptions.dart';
import '../../providers/recipe_editor_provider.dart';

/// Chọn ảnh từ thư viện, tải lên và trả về URL. Trả về `null` nếu người dùng
/// huỷ hoặc tải thất bại; khi đó hiện thông báo và mọi dữ liệu đang nhập được
/// giữ nguyên (offline → `recipes.err_offline_image`).
Future<String?> pickAndUploadImage(BuildContext context) async {
  final provider = context.read<RecipeEditorProvider>();
  final messenger = ScaffoldMessenger.of(context);

  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1600,
    imageQuality: 85,
  );
  if (picked == null) return null;

  final url = await provider.uploadImage(File(picked.path));
  if (url == null) {
    final offline = provider.uploadError is OfflineException;
    messenger.showSnackBar(SnackBar(
      content: Text(offline ? 'recipes.err_offline_image'.tr() : 'recipes.err_upload_failed'.tr()),
    ));
  }
  return url;
}
