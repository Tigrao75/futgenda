import 'package:flutter/material.dart';
import '../../services/group_service.dart';
import '../../models/group_model.dart';
import 'group_detail_page.dart';
import '../../services/auth_service.dart';

final GroupService _groupService = GroupService();
final AuthService _authService = AuthService();

class GroupListPage extends StatelessWidget {
  const GroupListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Futgenda'),
        actions: [
          IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await _authService.logout();

            if (!context.mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
        (route) => false,
      );
        },
          ),
        ],
      ),
      body: StreamBuilder<List<Group>>(
      stream: _groupService.getGroups(),
      builder: (context, snapshot) {
        // Log snapshot state
        debugPrint('[GroupListPage] Connection state: ${snapshot.connectionState}');
        debugPrint('[GroupListPage] Has error: ${snapshot.hasError}');
        if (snapshot.hasError) {
          debugPrint('[GroupListPage] Error: ${snapshot.error}');
        }
        debugPrint('[GroupListPage] Has data: ${snapshot.hasData}');
        if (snapshot.hasData) {
          debugPrint('[GroupListPage] Data length: ${snapshot.data!.length}');
        }

        if (snapshot.hasError) {
          debugPrint('Erro no stream: ${snapshot.error.toString()}');

          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Erro ao carregar grupos'),
                SizedBox(height: 8),
                Text(
                  'Verifique o índice do Firestore',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Nenhum grupo ainda'));
        }

        final groups = snapshot.data!;

        return ListView.builder(
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];

            return ListTile(
              title: Text(group.name),
              subtitle: Text(
                '${group.eventDay} • ${group.startTime} - ${group.endTime}',
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GroupDetailPage(groupId: group.id),
                  ),
                );
              },
            );
          },
        );
      },
      ),


  floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/create-group');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}