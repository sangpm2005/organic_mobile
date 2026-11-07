import 'package:flutter/material.dart';

import '../../domain/product_detail.dart';
import 'product_photo.dart';

class ProductGallery extends StatefulWidget {
  final List<ProductImage> images;
  const ProductGallery(this.images, {super.key});
  @override
  State<ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends State<ProductGallery> {
  final controller = PageController();
  int index = 0;

  @override
  void didUpdateWidget(ProductGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (index >= widget.images.length) {
      index = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && controller.hasClients) controller.jumpToPage(0);
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    if (images.isEmpty) {
      return const AspectRatio(aspectRatio: 1, child: ProductPhoto(''));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 1,
            child: PageView.builder(
              key: const ValueKey('product.gallery.pages'),
              controller: controller,
              itemCount: images.length,
              onPageChanged: (value) => setState(() => index = value),
              itemBuilder: (context, page) => Semantics(
                label: images[page].alt,
                button: true,
                child: GestureDetector(
                  onTap: () => openViewer(page),
                  child: ProductPhoto(images[page].url),
                ),
              ),
            ),
          ),
        ),
        Row(
          children: [
            Expanded(child: Text('Ảnh ${index + 1}/${images.length}')),
            IconButton(
              key: const ValueKey('product.gallery.expand'),
              tooltip: 'Phóng to ảnh sản phẩm',
              onPressed: () => openViewer(index),
              icon: const Icon(Icons.zoom_in),
            ),
          ],
        ),
        if (images.length > 1) ...[
          const Text('Vuốt ảnh hoặc chọn ảnh bên dưới để xem các góc khác.'),
          const SizedBox(height: 8),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, page) => Semantics(
                selected: page == index,
                child: InkWell(
                  key: ValueKey('product.gallery.thumbnail.$page'),
                  onTap: () => controller.animateToPage(
                    page,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  ),
                  child: Container(
                    width: 76,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        width: page == index ? 2 : 1,
                        color: page == index
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).dividerColor,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: ProductPhoto(images[page].url),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void openViewer(int page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ProductImageViewer(widget.images, page),
      ),
    );
  }
}

class _ProductImageViewer extends StatefulWidget {
  final List<ProductImage> images;
  final int initialIndex;
  const _ProductImageViewer(this.images, this.initialIndex);
  @override
  State<_ProductImageViewer> createState() => _ProductImageViewerState();
}

class _ProductImageViewerState extends State<_ProductImageViewer> {
  late final controller = PageController(initialPage: widget.initialIndex);
  late int index = widget.initialIndex;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Ảnh ${index + 1}/${widget.images.length}')),
    body: SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Dùng hai ngón tay để phóng to; vuốt để đổi ảnh.'),
          ),
          Expanded(
            child: PageView.builder(
              key: const ValueKey('product.gallery.viewer'),
              controller: controller,
              itemCount: widget.images.length,
              onPageChanged: (value) => setState(() => index = value),
              itemBuilder: (context, page) => InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(child: ProductPhoto(widget.images[page].url)),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
