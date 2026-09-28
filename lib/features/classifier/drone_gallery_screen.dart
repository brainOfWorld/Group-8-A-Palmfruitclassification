import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/colors.dart';

class DroneGalleryScreen extends StatefulWidget {
  const DroneGalleryScreen({super.key});

  @override
  State<DroneGalleryScreen> createState() => _DroneGalleryScreenState();
}

class _DroneGalleryScreenState extends State<DroneGalleryScreen> {
  final Set<AssetEntity> _selectedAssets = {};
  List<AssetEntity> _assets = [];
  bool _isLoading = true;
  final OrderOptionType _currentSortType = OrderOptionType.createDate;
  final bool _isAscending = false;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    final status = await Permission.photos.request();
    if (status.isGranted || status.isLimited) {
      try {
        final filter = FilterOptionGroup(
          orders: [OrderOption(type: _currentSortType, asc: _isAscending)],
        );
        final paths = await PhotoManager.getAssetPathList(
          type: RequestType.image,
          filterOption: filter,
          hasAll: true,
        );
        if (paths.isNotEmpty) {
          final assets = await paths[0].getAssetListPaged(
            page: 0,
            size: 200,
          );
          setState(() {
            _assets = assets;
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      } catch (e) {
        debugPrint("Gallery load error: ");
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _toggleSelection(AssetEntity asset) {
    setState(() {
      if (_selectedAssets.contains(asset)) {
        _selectedAssets.remove(asset);
      } else {
        _selectedAssets.add(asset);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.containerBg,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context, _selectedAssets.toList()),
        ),
        title: const Text(
          "DRONE GALLERY",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: Colors.white,
          ),
        ),
        actions: [
          if (_selectedAssets.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(context, _selectedAssets.toList()),
              child: Text(
                "Select (${_selectedAssets.length})",
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.neonOrange,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.neonOrange),
            )
          : _assets.isEmpty
              ? _buildEmptyState()
              : _buildGrid(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 64,
            color: AppColors.neonOrange.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            "NO IMAGES FOUND",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Aerial photos will appear here",
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: _assets.length,
      itemBuilder: (context, index) {
        final asset = _assets[index];
        final isSelected = _selectedAssets.contains(asset);
        return _buildGridItem(asset, isSelected, index);
      },
    );
  }

  Widget _buildGridItem(AssetEntity asset, bool isSelected, int index) {
    return GestureDetector(
      onTap: () => _toggleSelection(asset),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: AppColors.neonOrange, width: 3)
              : Border.all(color: Colors.transparent, width: 3),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _AssetThumbnail(asset: asset),
              if (isSelected)
                Container(
                  color: AppColors.neonOrange.withValues(alpha: 0.25),
                  child: const Center(
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.neonOrange,
                      size: 36,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetThumbnail extends StatelessWidget {
  final AssetEntity asset;

  const _AssetThumbnail({required this.asset});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailDataWithSize(const ThumbnailSize(400, 400)),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(snapshot.data!, fit: BoxFit.cover);
        }
        return Container(
          color: AppColors.containerBg,
          child: const Center(
            child: Icon(Icons.image_outlined, color: Color(0xFF757575)),
          ),
        );
      },
    );
  }
}
