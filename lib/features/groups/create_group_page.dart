import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../services/group_service.dart';
import '../../models/group_model.dart';
import '../../services/auth_service.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});
  

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _nameController = TextEditingController();
  final GroupService _groupService = GroupService();
  final uuid = const Uuid();
  final AuthService _authService = AuthService();
   int maxParticipants = 10;
  bool isLoading = false;

  String selectedDay = 'Tuesday';

  TimeOfDay startTime = const TimeOfDay(hour: 19, minute: 0);
  TimeOfDay endTime = const TimeOfDay(hour: 21, minute: 0);

  

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? startTime : endTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null) {
    
      setState(() {
        if (isStart) {
          startTime = picked;
        } else {
          endTime = picked;
        }
      });

    }
  }

  String formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar Grupo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome do grupo'),
            ),

            Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    const Text(
      'Máx. participantes',
      style: TextStyle(fontSize: 16),
    ),
    Row(
      children: [
        IconButton(
          onPressed: () {
            if (maxParticipants > 1) {
              setState(() => maxParticipants--);
            }
          },
          icon: const Icon(Icons.remove),
        ),
        Text(
          maxParticipants.toString(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          onPressed: () {
            if (maxParticipants < 99) {
              setState(() => maxParticipants++);
            }
          },
          icon: const Icon(Icons.add),
        ),
      ],
    ),
  ],
),

            const SizedBox(height: 20),

            // DIA DA SEMANA
            Row(
              children: [
                const Text(
                  'Dia da semana:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: selectedDay,
                  items: [
                    'Monday',
                    'Tuesday',
                    'Wednesday',
                    'Thursday',
                    'Friday',
                    'Saturday',
                    'Sunday'
                  ].map((day) {
                    return DropdownMenuItem(
                        value: day, child: Text(day));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedDay = value!;
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            // HORÁRIO INÍCIO
            ListTile(
              title: const Text('Horário de início'),
              subtitle: Text(formatTime(startTime)),
              trailing: const Icon(Icons.access_time),
              onTap: () => _selectTime(context, true),
            ),

            // HORÁRIO FIM
            ListTile(
              title: const Text('Horário de término'),
              subtitle: Text(formatTime(endTime)),
              trailing: const Icon(Icons.access_time),
              onTap: () => _selectTime(context, false),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: isLoading ? null : () async {
                setState(() => isLoading = true);

                if (_nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Informe o nome do grupo')),
                  );
                  setState(() => isLoading = false);
                  return;
                }

                final group = Group(
                id: uuid.v4(),
                name: _nameController.text,
                ownerId: _authService.currentUser?.uid ?? 'temp-user',
                maxParticipants: maxParticipants,
                eventDay: selectedDay,
                startTime: formatTime(startTime),
                endTime: formatTime(endTime),
                );

              await _groupService.createGroup(group);

              if (!mounted) return;

              setState(() => isLoading = false);

              Navigator.pop(context);
        },
              child: isLoading
              ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
              : const Text('Criar Grupo'),
            )
          ],
        ),
      ),
    );
  }
}