// Arabic labels for codes the API returns (the CRM's own wording).

const taskStatus = {'todo': 'لسه', 'doing': 'شغال فيها', 'review': 'مستنية مراجعة', 'done': 'خلصت'};
const taskPriority = {'normal': 'عادية', 'high': 'مهمة', 'urgent': 'عاجلة'};
const ticketStatus = {'open': 'مفتوحة', 'progress': 'جاري الشغل', 'waiting': 'مستنيين العميل', 'resolved': 'اتحلت'};
const ticketPriority = {'normal': 'عادية', 'urgent': 'عاجلة', 'critical': 'حرجة'};
const ticketType = {'bug': 'مشكلة', 'change': 'تعديل', 'question': 'سؤال'};
const projectStage = {'discovery': 'استكشاف', 'design': 'تصميم', 'dev': 'تطوير', 'test': 'اختبار', 'live': 'شغال', 'paused': 'متوقف'};
const invoiceStatus = {'draft': 'مسودة', 'sent': 'اتبعتت', 'partial': 'مدفوعة جزئي', 'paid': 'مدفوعة'};
const leaveStatus = {'pending': 'مستنية', 'approved': 'اتوافق عليها', 'rejected': 'اترفضت', 'cancelled': 'اتلغت'};
const leaveType = {'annual': 'اعتيادية', 'casual': 'عارضة', 'sick': 'مرضية', 'unpaid': 'بدون مرتب', 'other': 'أخرى'};
const attStatus = {'present': 'حاضر', 'late': 'متأخر', 'absent': 'غايب', 'excused': 'غياب بإذن', 'remote': 'من البيت', 'leave': 'إجازة', 'holiday': 'عطلة', 'off': 'راحة', 'future': '', 'before': ''};
const appStatus = {'new': 'جديد', 'reviewing': 'بنراجعه', 'interview': 'مقابلة', 'offer': 'عرض', 'hired': 'اتعيّن', 'rejected': 'اترفض'};
const activityType = {'call': 'مكالمة', 'meeting': 'اجتماع', 'lunch': 'غدا عمل', 'note': 'ملاحظة', 'task': 'مهمة', 'email': 'إيميل', 'file': 'ملف', 'system': 'النظام'};
const slipStatus = {'draft': 'مسودة', 'approved': 'اتعتمد', 'paid': 'اتصرف'};
const leadStatus = {'open': 'مفتوح', 'won': 'اتكسب', 'lost': 'اتخسر'};

String lbl(Map<String, String> m, String k) => m[k] ?? k;
