// Data the app shows. Every model reads the JSON of the code it mobile API (/api/mobile/v1),
// and tolerates missing fields so a newer server never crashes an older app.

typedef J = Map<String, dynamic>;

String _s(dynamic v) => v == null ? '' : v.toString();
int _i(dynamic v) => v is int ? v : int.tryParse(_s(v)) ?? 0;
double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse(_s(v)) ?? 0;
bool _b(dynamic v) => v == true || v == 1 || v == '1';
DateTime? _t(dynamic v) => v == null || v == '' ? null : DateTime.tryParse(_s(v))?.toLocal();
List<T> _l<T>(dynamic v, T Function(J) f) => v is List ? v.whereType<Map>().map((e) => f(J.from(e))).toList() : <T>[];
List<String> _ls(dynamic v) => v is List ? v.map(_s).toList() : <String>[];

class Page<T> {
  Page(this.items, {this.total = 0, this.page = 1, this.lastPage = 1});
  final List<T> items;
  final int total, page, lastPage;
  bool get hasMore => page < lastPage;
  static Page<T> from<T>(J j, T Function(J) f) => Page(
        _l(j['data'], f),
        total: _i(j['meta']?['total'] ?? j['total']),
        page: _i(j['meta']?['current_page'] ?? 1),
        lastPage: _i(j['meta']?['last_page'] ?? 1),
      );
}

class Me {
  Me({required this.id, required this.name, required this.email, this.role = '', this.avatar, this.permissions = const [], this.department, this.employeeCode, this.isAdmin = false, this.isManager = false});
  final int id;
  final String name, email, role;
  final String? avatar, department, employeeCode;
  final List<String> permissions;
  final bool isAdmin, isManager;
  bool can(String p) => isAdmin || permissions.any((x) => x == p || p.startsWith('$x.'));
  String get first => name.split(' ').first;
  factory Me.fromJson(J j) => Me(
        id: _i(j['id']),
        name: _s(j['name']),
        email: _s(j['email']),
        role: _s(j['role']),
        avatar: j['avatar'] as String?,
        permissions: _ls(j['permissions']),
        department: j['department'] as String?,
        employeeCode: j['employee_code'] as String?,
        isAdmin: _b(j['is_admin']),
        isManager: _b(j['is_manager']),
      );
}

class Ref {
  Ref(this.id, this.name);
  final int id;
  final String name;
  static Ref? from(dynamic j) => j is Map ? Ref(_i(j['id']), _s(j['name'])) : null;
}

class Dashboard {
  Dashboard({required this.sentence, required this.kpis, required this.stages, required this.myTasks, required this.slaTickets, required this.today});
  final String sentence;
  final List<Kpi> kpis;
  final List<StageCount> stages;
  final List<TaskItem> myTasks;
  final List<Ticket> slaTickets;
  final List<Activity> today;
  factory Dashboard.fromJson(J j) => Dashboard(
        sentence: _s(j['sentence']),
        kpis: _l(j['kpis'], Kpi.fromJson),
        stages: _l(j['pipeline'], StageCount.fromJson),
        myTasks: _l(j['my_tasks'], TaskItem.fromJson),
        slaTickets: _l(j['sla_tickets'], Ticket.fromJson),
        today: _l(j['today'], Activity.fromJson),
      );
}

class Kpi {
  Kpi(this.key, this.label, this.value, {this.delta, this.unit});
  final String key, label, value;
  final String? delta, unit;
  factory Kpi.fromJson(J j) => Kpi(_s(j['key']), _s(j['label']), _s(j['value']), delta: j['delta'] as String?, unit: j['unit'] as String?);
}

class StageCount {
  StageCount(this.name, this.count, this.value, {this.code = ''});
  final String name, code;
  final int count;
  final double value;
  factory StageCount.fromJson(J j) => StageCount(_s(j['name']), _i(j['count']), _d(j['value']), code: _s(j['code']));
}

class Pipeline {
  Pipeline(this.id, this.name, this.stages, {this.isDefault = false});
  final int id;
  final String name;
  final List<Stage> stages;
  final bool isDefault;
  factory Pipeline.fromJson(J j) => Pipeline(_i(j['id']), _s(j['name']), _l(j['stages'], Stage.fromJson), isDefault: _b(j['is_default']));
}

class Stage {
  Stage(this.id, this.code, this.name, this.probability);
  final int id, probability;
  final String code, name;
  bool get isWon => code == 'won';
  bool get isLost => code == 'lost';
  factory Stage.fromJson(J j) => Stage(_i(j['id']), _s(j['code']), _s(j['name']), _i(j['probability']));
}

class Lead {
  Lead({required this.id, required this.title, this.value = 0, this.stageId = 0, this.stage = '', this.stageCode = '', this.person, this.organization, this.owner, this.source, this.type, this.expectedClose, this.createdAt, this.rottenDays = 0, this.description = '', this.phone, this.email, this.tags = const []});
  final int id, stageId, rottenDays;
  final String title, stage, stageCode, description;
  final double value;
  final Ref? person, organization, owner;
  final String? source, type, phone, email;
  final DateTime? expectedClose, createdAt;
  final List<String> tags;
  factory Lead.fromJson(J j) => Lead(
        id: _i(j['id']),
        title: _s(j['title']),
        value: _d(j['value']),
        stageId: _i(j['stage']?['id'] ?? j['stage_id']),
        stage: _s(j['stage']?['name']),
        stageCode: _s(j['stage']?['code']),
        person: Ref.from(j['person']),
        organization: Ref.from(j['organization']),
        owner: Ref.from(j['owner']),
        source: j['source'] as String?,
        type: j['type'] as String?,
        expectedClose: _t(j['expected_close_date']),
        createdAt: _t(j['created_at']),
        rottenDays: _i(j['rotten_days']),
        description: _s(j['description']),
        phone: j['phone'] as String?,
        email: j['email'] as String?,
        tags: _ls(j['tags']),
      );
}

class Person {
  Person({required this.id, required this.name, this.emails = const [], this.phones = const [], this.organization, this.jobTitle, this.leadsCount = 0});
  final int id, leadsCount;
  final String name;
  final List<String> emails, phones;
  final Ref? organization;
  final String? jobTitle;
  factory Person.fromJson(J j) => Person(
        id: _i(j['id']),
        name: _s(j['name']),
        emails: _ls(j['emails']),
        phones: _ls(j['phones']),
        organization: Ref.from(j['organization']),
        jobTitle: j['job_title'] as String?,
        leadsCount: _i(j['leads_count']),
      );
}

class Organization {
  Organization({required this.id, required this.name, this.address = '', this.personsCount = 0});
  final int id, personsCount;
  final String name, address;
  factory Organization.fromJson(J j) => Organization(id: _i(j['id']), name: _s(j['name']), address: _s(j['address']), personsCount: _i(j['persons_count']));
}

class Activity {
  Activity({required this.id, required this.type, required this.title, this.comment = '', this.from, this.to, this.done = false, this.lead, this.person, this.owner, this.location});
  final int id;
  final String type, title, comment;
  final DateTime? from, to;
  final bool done;
  final Ref? lead, person, owner;
  final String? location;
  factory Activity.fromJson(J j) => Activity(
        id: _i(j['id']),
        type: _s(j['type']),
        title: _s(j['title']),
        comment: _s(j['comment']),
        from: _t(j['schedule_from']),
        to: _t(j['schedule_to']),
        done: _b(j['is_done']),
        lead: Ref.from(j['lead']),
        person: Ref.from(j['person']),
        owner: Ref.from(j['user']),
        location: j['location'] as String?,
      );
}

class Quote {
  Quote({required this.id, required this.subject, this.person, this.total = 0, this.expiredAt, this.lead, this.items = const []});
  final int id;
  final String subject;
  final Ref? person, lead;
  final double total;
  final DateTime? expiredAt;
  final List<LineItem> items;
  factory Quote.fromJson(J j) => Quote(
        id: _i(j['id']),
        subject: _s(j['subject']),
        person: Ref.from(j['person']),
        lead: Ref.from(j['lead']),
        total: _d(j['grand_total']),
        expiredAt: _t(j['expired_at']),
        items: _l(j['items'], LineItem.fromJson),
      );
}

class LineItem {
  LineItem(this.name, this.qty, this.price, this.total);
  final String name;
  final double qty, price, total;
  factory LineItem.fromJson(J j) => LineItem(_s(j['name']), _d(j['quantity']), _d(j['price']), _d(j['total']));
}

class Product {
  Product({required this.id, required this.name, this.sku = '', this.price = 0, this.quantity = 0, this.description = ''});
  final int id;
  final String name, sku, description;
  final double price, quantity;
  factory Product.fromJson(J j) => Product(id: _i(j['id']), name: _s(j['name']), sku: _s(j['sku']), price: _d(j['price']), quantity: _d(j['quantity']), description: _s(j['description']));
}

class Mail {
  Mail({required this.id, required this.subject, required this.from, this.snippet = '', this.at, this.read = true, this.folder = 'inbox', this.body = '', this.attachments = const []});
  final int id;
  final String subject, from, snippet, folder, body;
  final DateTime? at;
  final bool read;
  final List<FileRef> attachments;
  factory Mail.fromJson(J j) => Mail(
        id: _i(j['id']),
        subject: _s(j['subject']),
        from: _s(j['from']),
        snippet: _s(j['snippet']),
        at: _t(j['created_at']),
        read: _b(j['is_read'] ?? true),
        folder: _s(j['folder']),
        body: _s(j['body']),
        attachments: _l(j['attachments'], FileRef.fromJson),
      );
}

class FileRef {
  FileRef(this.name, this.url, {this.size = 0, this.mime = ''});
  final String name, url, mime;
  final int size;
  bool get isImage => mime.startsWith('image/');
  factory FileRef.fromJson(J j) => FileRef(_s(j['name']), _s(j['url']), size: _i(j['size']), mime: _s(j['mime']));
}

class Project {
  Project({required this.id, required this.name, this.code = '', this.client, this.status = '', this.progress = 0, this.due, this.members = const [], this.open = 0, this.done = 0, this.description = '', this.budget});
  final int id, open, done;
  final String name, code, status, description;
  final Ref? client;
  final double progress;
  final DateTime? due;
  final List<Ref> members;
  final double? budget;
  factory Project.fromJson(J j) => Project(
        id: _i(j['id']),
        name: _s(j['name']),
        code: _s(j['code']),
        client: Ref.from(j['client']),
        status: _s(j['status']),
        progress: _d(j['progress']),
        due: _t(j['due_date']),
        members: _l(j['members'], (m) => Ref(_i(m['id']), _s(m['name']))),
        open: _i(j['tasks_open']),
        done: _i(j['tasks_done']),
        description: _s(j['description']),
        budget: j['budget'] == null ? null : _d(j['budget']),
      );
}

class TaskItem {
  TaskItem({required this.id, required this.title, this.project, this.status = 'todo', this.priority = 'normal', this.due, this.assignee, this.department, this.description = ''});
  final int id;
  final String title, status, priority, description;
  final Ref? project, assignee;
  final String? department;
  final DateTime? due;
  bool get isDone => status == 'done';
  bool get overdue => !isDone && due != null && due!.isBefore(DateTime.now());
  factory TaskItem.fromJson(J j) => TaskItem(
        id: _i(j['id']),
        title: _s(j['title']),
        project: Ref.from(j['project']),
        status: _s(j['status']),
        priority: _s(j['priority']),
        due: _t(j['due_date']),
        assignee: Ref.from(j['assignee']),
        department: j['department'] as String?,
        description: _s(j['description']),
      );
}

class Ticket {
  Ticket({required this.id, required this.number, required this.subject, this.client, this.priority = 'normal', this.status = 'open', this.slaDue, this.assignee, this.messages = const [], this.project, this.createdAt});
  final int id;
  final String number, subject, priority, status;
  final Ref? client, assignee, project;
  final DateTime? slaDue, createdAt;
  final List<TicketMsg> messages;
  bool get closed => status == 'closed' || status == 'resolved';
  Duration? get slaLeft => slaDue?.difference(DateTime.now());
  factory Ticket.fromJson(J j) => Ticket(
        id: _i(j['id']),
        number: _s(j['number']),
        subject: _s(j['subject']),
        client: Ref.from(j['client']),
        project: Ref.from(j['project']),
        priority: _s(j['priority']),
        status: _s(j['status']),
        slaDue: _t(j['sla_due_at']),
        createdAt: _t(j['created_at']),
        assignee: Ref.from(j['assignee']),
        messages: _l(j['messages'], TicketMsg.fromJson),
      );
}

class TicketMsg {
  TicketMsg({required this.author, required this.body, this.at, this.fromClient = false, this.internal = false, this.files = const []});
  final String author, body;
  final DateTime? at;
  final bool fromClient, internal;
  final List<FileRef> files;
  factory TicketMsg.fromJson(J j) => TicketMsg(
        author: _s(j['author']),
        body: _s(j['body']),
        at: _t(j['created_at']),
        fromClient: _b(j['from_client']),
        internal: _b(j['internal']),
        files: _l(j['files'], FileRef.fromJson),
      );
}

class ChatThread {
  ChatThread({required this.id, required this.name, this.group = false, this.last = '', this.unread = 0, this.at, this.online = false});
  final int id, unread;
  final String name, last;
  final bool group, online;
  final DateTime? at;
  factory ChatThread.fromJson(J j) => ChatThread(
        id: _i(j['id']),
        name: _s(j['name']),
        group: _b(j['is_group']),
        last: _s(j['last_message']),
        unread: _i(j['unread']),
        at: _t(j['updated_at']),
        online: _b(j['online']),
      );
}

class ChatMsg {
  ChatMsg({required this.id, required this.sender, required this.body, this.mine = false, this.at, this.file});
  final int id;
  final String sender, body;
  final bool mine;
  final DateTime? at;
  final FileRef? file;
  factory ChatMsg.fromJson(J j) => ChatMsg(
        id: _i(j['id']),
        sender: _s(j['sender']),
        body: _s(j['body']),
        mine: _b(j['mine']),
        at: _t(j['created_at']),
        file: j['file'] is Map ? FileRef.fromJson(J.from(j['file'])) : null,
      );
}

class Employee {
  Employee({required this.id, required this.code, required this.name, this.jobTitle = '', this.department = '', this.status = 'active', this.phone, this.email, this.hiredAt, this.manager = false, this.todayIn, this.todayOut});
  final int id;
  final String code, name, jobTitle, department, status;
  final String? phone, email;
  final DateTime? hiredAt, todayIn, todayOut;
  final bool manager;
  factory Employee.fromJson(J j) => Employee(
        id: _i(j['id']),
        code: _s(j['code']),
        name: _s(j['name']),
        jobTitle: _s(j['job_title']),
        department: _s(j['department']),
        status: _s(j['status']),
        phone: j['phone'] as String?,
        email: j['email'] as String?,
        hiredAt: _t(j['hired_at']),
        manager: _b(j['is_manager']),
        todayIn: _t(j['today_in']),
        todayOut: _t(j['today_out']),
      );
}

class Department {
  Department(this.id, this.name, this.prefix, this.count, {this.manager});
  final int id, count;
  final String name, prefix;
  final String? manager;
  factory Department.fromJson(J j) => Department(_i(j['id']), _s(j['name']), _s(j['prefix']), _i(j['employees_count']), manager: j['manager'] as String?);
}

class Attendance {
  Attendance({this.checkIn, this.checkOut, this.late = 0, this.start = '09:00', this.end = '17:00', this.month = const []});
  final DateTime? checkIn, checkOut;
  final int late;
  final String start, end;
  final List<AttendanceDay> month;
  bool get inside => checkIn != null && checkOut == null;
  factory Attendance.fromJson(J j) => Attendance(
        checkIn: _t(j['check_in']),
        checkOut: _t(j['check_out']),
        late: _i(j['late_minutes']),
        start: _s(j['work_start'] ?? '09:00'),
        end: _s(j['work_end'] ?? '17:00'),
        month: _l(j['month'], AttendanceDay.fromJson),
      );
}

class AttendanceDay {
  AttendanceDay(this.date, this.state, {this.inAt, this.outAt, this.late = 0});
  final DateTime date;
  final String state; // present, late, absent, leave, off, holiday
  final String? inAt, outAt;
  final int late;
  factory AttendanceDay.fromJson(J j) => AttendanceDay(_t(j['date']) ?? DateTime.now(), _s(j['state']), inAt: j['in'] as String?, outAt: j['out'] as String?, late: _i(j['late_minutes']));
}

class Leave {
  Leave({required this.id, required this.type, required this.from, required this.to, this.days = 1, this.status = 'pending', this.employee, this.reason = '', this.note});
  final int id;
  final String type, status, reason;
  final DateTime from, to;
  final double days;
  final Ref? employee;
  final String? note;
  factory Leave.fromJson(J j) => Leave(
        id: _i(j['id']),
        type: _s(j['type']),
        from: _t(j['from']) ?? DateTime.now(),
        to: _t(j['to']) ?? DateTime.now(),
        days: _d(j['days']),
        status: _s(j['status']),
        employee: Ref.from(j['employee']),
        reason: _s(j['reason']),
        note: j['manager_note'] as String?,
      );
}

class LeaveBalance {
  LeaveBalance(this.total, this.used, this.casualLeft);
  final double total, used, casualLeft;
  double get left => total - used;
  factory LeaveBalance.fromJson(J j) => LeaveBalance(_d(j['total']), _d(j['used']), _d(j['casual_left']));
}

class Payslip {
  Payslip({required this.id, required this.month, this.net = 0, this.gross = 0, this.status = 'draft', this.lines = const [], this.employee});
  final int id;
  final String month, status;
  final double net, gross;
  final List<PayLine> lines;
  final Ref? employee;
  factory Payslip.fromJson(J j) => Payslip(
        id: _i(j['id']),
        month: _s(j['month']),
        net: _d(j['net']),
        gross: _d(j['gross']),
        status: _s(j['status']),
        lines: _l(j['lines'], PayLine.fromJson),
        employee: Ref.from(j['employee']),
      );
}

class PayLine {
  PayLine(this.label, this.amount, this.kind);
  final String label, kind; // earning | deduction
  final double amount;
  factory PayLine.fromJson(J j) => PayLine(_s(j['label']), _d(j['amount']), _s(j['kind']));
}

class Application {
  Application({required this.id, required this.name, required this.position, this.status = 'new', this.at, this.email, this.phone, this.cv, this.answers = const {}});
  final int id;
  final String name, position, status;
  final DateTime? at;
  final String? email, phone;
  final FileRef? cv;
  final Map<String, String> answers;
  factory Application.fromJson(J j) => Application(
        id: _i(j['id']),
        name: _s(j['name']),
        position: _s(j['position']),
        status: _s(j['status']),
        at: _t(j['created_at']),
        email: j['email'] as String?,
        phone: j['phone'] as String?,
        cv: j['cv'] is Map ? FileRef.fromJson(J.from(j['cv'])) : null,
        answers: j['answers'] is Map ? (j['answers'] as Map).map((k, v) => MapEntry(_s(k), _s(v))) : const {},
      );
}

class Invoice {
  Invoice({required this.id, required this.number, this.client, this.total = 0, this.paid = 0, this.status = 'draft', this.due, this.issued});
  final int id;
  final String number, status;
  final Ref? client;
  final double total, paid;
  final DateTime? due, issued;
  double get left => total - paid;
  factory Invoice.fromJson(J j) => Invoice(
        id: _i(j['id']),
        number: _s(j['number']),
        client: Ref.from(j['client']),
        total: _d(j['total']),
        paid: _d(j['paid']),
        status: _s(j['status']),
        due: _t(j['due_date']),
        issued: _t(j['issued_at']),
      );
}

class Notice {
  Notice({required this.id, required this.title, this.body = '', this.at, this.read = false, this.link, this.kind = ''});
  final int id;
  final String title, body, kind;
  final DateTime? at;
  final bool read;
  final String? link;
  factory Notice.fromJson(J j) => Notice(id: _i(j['id']), title: _s(j['title']), body: _s(j['body']), at: _t(j['created_at']), read: _b(j['is_read']), link: j['link'] as String?, kind: _s(j['kind']));
}
