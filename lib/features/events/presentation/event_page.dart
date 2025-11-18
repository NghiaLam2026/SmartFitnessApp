import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:smart_fitness_app/features/events/domain/event_model.dart';
import 'package:smart_fitness_app/features/events/infrastructure/event_repository.dart';
import 'package:smart_fitness_app/features/events/infrastructure/event_repository_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventPage extends StatefulWidget {
  const EventPage({super.key});

  @override
  State<EventPage> createState() => _EventPageState();
}

class _EventPageState extends State<EventPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime? dateFilter;
  var showCreate = false;
  final eventRepository = EventRepositoryImpl(client: Supabase.instance.client);
  @override
  void initState() {
    _tabController = TabController(length: 2, vsync: this);
    initialize();
    super.initState();
  }

  Future initialize() async {
    final data = await eventRepository.checkingAdmin();
    if (data) {
      setState(() {
        showCreate = data;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      eventRepository.readAllCategoryEvent();
                    });
                  },
                  child: _all_event(),
                ),
                _register_event(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: showCreate
          ? FloatingActionButton(
              onPressed: () {
                context.push('/home/events/createEvent');
              },
              child: Icon(Icons.add),
            )
          : null,

      appBar: AppBar(
        title: Text("Events"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "All Events"),
            Tab(text: "Registered"),
          ],
        ),
      ),
    );
  }

  Widget _all_event() {
    return StreamBuilder(
      stream: eventRepository.readAllCategoryEvent(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text("Something went wrong");
        }
        if (snapshot.hasData) {
          final events = snapshot.data ?? [];
          return ListView.builder(
            padding: EdgeInsets.all(20),
            itemCount: events.length,
            itemBuilder: (context, index) {
              return Card(
                child: ListTile(
                  onTap: () {
                    context.push(
                      '/home/events/eventDetail/${events[index].id}',
                    );
                  },
                  title: Text(events[index].name),
                  subtitle: Text(
                    "${events[index].venue ?? "NA"} || ${events[index].startsAt != null ? DateFormat.yMMMEd().format(events[index].startsAt!) : "NA"}",
                  ),
                ),
              );
            },
          );
        }
        return SizedBox();
      },
    );
  }

  Widget _register_event() {
    return StreamBuilder(
      stream: eventRepository.readAllRegisterEvent(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text("Something went wrong");
        }
        if (snapshot.hasData) {
          final events = snapshot.data ?? [];
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                eventRepository.readAllRegisterEvent();
              });
            },
            child: ListView.builder(
              padding: EdgeInsets.all(20),
              itemCount: events.length,
              itemBuilder: (context, index) {
                return Card(
                  child: ListTile(
                    onTap: () {
                      context.push(
                        '/home/events/eventDetail/${events[index].id}',
                      );
                    },
                    title: Text(events[index].eventName),
                    subtitle: Text(
                      "${events[index].eventVenue ?? "NA"} || ${events[index].eventStartDate != null ? DateFormat.yMMMEd().format(events[index].eventStartDate!) : "NA"}",
                    ),
                  ),
                );
              },
            ),
          );
        }
        return SizedBox();
      },
    );
  }
}
