import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../providers/cooking_mode_provider.dart';
import '../display_helpers.dart';
import 'servings_stepper.dart';

/// Ngăn kéo xem nhanh nguyên liệu ngay trong chế độ nấu, có chỉnh khẩu phần.
/// Đổi khẩu phần ở đây quy đổi tức thì và được lưu cùng phiên nấu.
class CookingIngredientsDrawer extends StatelessWidget {
  const CookingIngredientsDrawer({super.key, required this.provider});

  final CookingModeProvider provider;

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final recipe = provider.recipe;
    final lines = scaledIngredientLines(recipe, provider.servings, lang);
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('recipes.ingredients'.tr(), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text('recipes.f_servings'.tr(), style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: ServingsStepper(value: provider.servings, onChanged: provider.setServings),
            ),
            if (provider.servings != recipe.baseServings)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'recipes.servings_original'.plural(recipe.baseServings),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const Divider(height: 24),
            for (final line in lines)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.circle, size: 8),
                minLeadingWidth: 12,
                title: Text(line, style: const TextStyle(fontSize: 18)),
              ),
          ],
        ),
      ),
    );
  }
}
