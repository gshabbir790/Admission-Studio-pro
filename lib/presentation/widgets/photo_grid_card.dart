import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/models/photo_item.dart';

/// One grid cell (spec §10): index badge, thumbnail, student name, and
/// edit/retake/delete actions. An empty (unfilled) slot shows a dashed
/// placeholder instead, matching the HTML grid's fixed-capacity layout.
class PhotoGridCard extends StatelessWidget {
  const PhotoGridCard({
    super.key,
    required this.index,
    required this.photo,
    required this.onEdit,
    required this.onRetake,
    required this.onDelete,
    required this.onRenameTap,
  });

  final int index;
  final PhotoItem? photo;
  final VoidCallback onEdit;
  final VoidCallback onRetake;
  final VoidCallback onDelete;
  final VoidCallback onRenameTap;

  @override
  Widget build(BuildContext context) {
    if (photo == null) {
      return DottedSlot(index: index);
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(photo!.originalPath),
            fit: BoxFit.cover,
            cacheWidth: 320,
            cacheHeight: 420,
            filterQuality: FilterQuality.medium,
          ),
          Positioned(
            top: 3,
            left: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$index',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: Row(
              children: [
                _MiniIconButton(icon: Icons.edit, onTap: onEdit),
                _MiniIconButton(icon: Icons.refresh, onTap: onRetake),
                _MiniIconButton(icon: Icons.delete_outline, onTap: onDelete),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: onRenameTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                color: Colors.black.withOpacity(0.55),
                child: Text(
                  photo!.nameEnabled && photo!.name.isNotEmpty
                      ? photo!.name
                      : '(no name)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 2),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 13, color: Colors.white),
      ),
    );
  }
}

class DottedSlot extends StatelessWidget {
  const DottedSlot({super.key, required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          style: BorderStyle.solid,
        ),
      ),
      child: Center(
        child: Text(
          '$index',
          style: TextStyle(color: Theme.of(context).disabledColor, fontSize: 12),
        ),
      ),
    );
  }
}
