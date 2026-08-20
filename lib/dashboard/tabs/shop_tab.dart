import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../shop/cart_page.dart';
import '../../shop/item_detail_page.dart';
import '../../shop/providers/cart_provider.dart';
import '../../shop/providers/item_provider.dart';
import '../../shop/widgets/product_card.dart';
import '../../theme/app_colors.dart';
import '../../widgets/glossy_widgets.dart';

class ShopTab extends StatefulWidget {
  const ShopTab({super.key});

  @override
  State<ShopTab> createState() => _ShopTabState();
}

class _ShopTabState extends State<ShopTab> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final provider = context.read<ItemProvider>();
    if (provider.items.isEmpty) {
      // Defer past this frame — didChangeDependencies runs while the
      // framework is still mid-build, and loadItems() calls
      // notifyListeners() synchronously before its first await, which
      // crashes if fired while a descendant (e.g. the search field's
      // focus scope) is still being built.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        provider.loadCategories();
        provider.loadItems(refresh: true);
      });
    }

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          provider.hasMore &&
          !provider.isLoading) {
        provider.loadItems();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            _Header(searchController: _searchController),
            _CategoryChips(),
            SizedBox(height: 4.h),
            Expanded(child: _ProductGrid(scrollController: _scrollController)),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.searchController});

  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(28.r)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.surface.withValues(alpha: 0.58),
                brandRed.withValues(alpha: 0.4),
              ],
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28.r)),
            boxShadow: [
              BoxShadow(
                color: brandRed.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Shop',
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                        color: brandRed,
                      ),
                    ),
                  ),
                  _CartButton(),
                ],
              ),
              SizedBox(height: 14.h),
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: brandRed.withValues(alpha: 0.12)),
                ),
                child: TextField(
                  controller: searchController,
                  style: TextStyle(fontSize: 14.sp),
                  decoration: InputDecoration(
                    hintText: 'Search products',
                    hintStyle: TextStyle(color: colors.textTertiary, fontSize: 14.sp),
                    prefixIcon: Icon(
                      Icons.search,
                      color: brandRed,
                      size: 20.sp,
                    ),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: colors.textTertiary),
                            onPressed: () {
                              searchController.clear();
                              context.read<ItemProvider>().onSearchChanged('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 13.h,
                    ),
                  ),
                  onChanged: (value) =>
                      context.read<ItemProvider>().onSearchChanged(value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final count = context.select<CartProvider, int>((c) => c.itemCount);

    return InkWell(
      borderRadius: BorderRadius.circular(24.r),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const CartPage())),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: EdgeInsets.all(9.w),
            decoration: BoxDecoration(
              color: brandRed.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_cart_outlined,
              color: brandRed,
              size: 20.sp,
            ),
          ),
          if (count > 0)
            Positioned(
              right: -2.w,
              top: -2.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [brandRed, brandRedDark],
                  ),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: context.colors.surface, width: 1.5),
                ),
                constraints: BoxConstraints(minWidth: 17.w),
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ItemProvider>(
      builder: (context, provider, _) {
        final colors = context.colors;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return SizedBox(
          height: 54.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h),
            itemCount: provider.categories.length,
            separatorBuilder: (_, _) => SizedBox(width: 10.w),
            itemBuilder: (context, index) {
              final category = provider.categories[index];
              final isSelected = category == provider.selectedCategory;

              return GestureDetector(
                onTap: () => provider.selectCategory(category),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.only(left: 6.w, right: 18.w),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isSelected
                          ? const [brandRed, brandRedDark]
                          : isDark
                              ? [colors.surface, brandRed.withValues(alpha: 0.15)]
                              : [colors.surface, const Color(0xFFFDECEC)],
                    ),
                    borderRadius: BorderRadius.circular(26.r),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? brandRed.withValues(alpha: 0.4)
                            : colors.shadow.withValues(alpha: 0.07),
                        blurRadius: isSelected ? 14 : 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 30.w,
                        height: 30.w,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.22)
                              : brandRed.withValues(alpha: 0.1),
                        ),
                        child: Icon(
                          isSelected
                              ? Icons.check_rounded
                              : Icons.sell_outlined,
                          size: 16.sp,
                          color: isSelected ? Colors.white : brandRed,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        category,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Consumer<ItemProvider>(
      builder: (context, provider, _) {
        if (provider.items.isEmpty && provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(
              color: brandRed,
              strokeWidth: 2.6,
            ),
          );
        }

        if (provider.items.isEmpty && provider.errorMessage != null) {
          return _MessageState(
            icon: Icons.wifi_off_rounded,
            title: 'Connection problem',
            subtitle: provider.errorMessage!,
            onRetry: () => provider.loadItems(refresh: true),
          );
        }

        if (provider.items.isEmpty) {
          return _MessageState(
            icon: Icons.search_off_rounded,
            title: 'No products found',
            subtitle: 'Try a different search or category',
          );
        }

        return GridView.builder(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12.w,
            mainAxisSpacing: 12.h,
            mainAxisExtent: 278.h,
          ),
          itemCount: provider.items.length + (provider.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= provider.items.length) {
              return const Center(
                child: CircularProgressIndicator(
                  color: brandRed,
                  strokeWidth: 2.4,
                ),
              );
            }
            final item = provider.items[index];
            return ProductCard(
              item: item,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ItemDetailPage(item: item)),
              ),
            );
          },
        );
      },
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: brandRed.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34.sp, color: brandRed),
          ),
          SizedBox(height: 16.h),
          Text(
            title,
            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40.w),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5.sp, color: colors.textSecondary),
            ),
          ),
          if (onRetry != null) ...[
            SizedBox(height: 16.h),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Retry',
                style: TextStyle(
                  color: brandRed,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.sp,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
