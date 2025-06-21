import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/room_provider.dart';
import '../widgets/loading_indicator.dart';
import '../models/user_room.dart';
import 'shop_order_page.dart';
import 'customer_page.dart';

class SavedRoomsPage extends StatefulWidget {
  const SavedRoomsPage({super.key});

  @override
  _SavedRoomsPageState createState() => _SavedRoomsPageState();
}

class _SavedRoomsPageState extends State<SavedRoomsPage> {
  @override
  void initState() {
    super.initState();
    _refreshOnInit();
  }

  Future<void> _refreshOnInit() async {
    await Future.microtask(() async {
      if (!mounted) return;
      await Provider.of<RoomProvider>(context, listen: false).refreshRooms();
    });
  }

  Future<void> _handlePullToRefresh() async {
    if (!mounted) return;
    try {
      await Provider.of<RoomProvider>(context, listen: false).refreshRooms();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error refreshing rooms: ${e.toString()}'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Saved Shops',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple, Colors.deepPurple.shade50],
            stops: const [0.0, 0.3],
          ),
        ),
        child: Consumer<RoomProvider>(
          builder: (context, roomProvider, child) {
            if (roomProvider.isLoading) {
              return Center(
                child: LoadingIndicator(
                  message: 'Loading saved shops...',
                  icon: Icons.store,
                  primaryColor: Colors.white,
                  backgroundColor: Colors.deepPurple.shade300,
                ),
              );
            }

            print('DEBUG: SavedRoomsPage - RoomProvider loaded');
            final shopRooms = roomProvider.shopRooms;
            print(
              'DEBUG: SavedRoomsPage - Shop rooms count: ${shopRooms.length}',
            );
            print(
              'DEBUG: SavedRoomsPage - Shop rooms: ${shopRooms.map((r) => '${r.name}(${r.category})').toList()}',
            );

            if (shopRooms.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.store_outlined, size: 64, color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'No saved shops',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Join a shop to see it here',
                      style: TextStyle(color: Colors.white.withOpacity(0.8)),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _handlePullToRefresh,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: shopRooms.length,
                itemBuilder: (context, index) {
                  return _buildShopCard(context, shopRooms[index]);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildShopCard(BuildContext context, UserRoom room) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          final auth = Provider.of<AuthProvider>(context, listen: false);
          CustomerPage.navigate(
            context,
            room.roomId,
            auth.user?.displayName ?? 'Customer',
            auth.user?.email ?? '',
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Colors.blue.shade50, Colors.white],
            ),
          ),
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.2),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.store,
                    color: Colors.blue.shade700,
                    size: 30,
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 6),
                    _buildStatusChip(
                      label: 'Shop',
                      color: Colors.blue,
                      icon: Icons.shopping_bag,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.blue.shade700,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip({
    required String label,
    required MaterialColor color,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color.shade700),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
