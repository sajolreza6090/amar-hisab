import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LedgerDb.instance.database;
  runApp(const AmarHisabApp());
}

final money = NumberFormat.currency(locale: 'bn_BD', symbol: '৳', decimalDigits: 0);

class LedgerDb {
  LedgerDb._();
  static final instance = LedgerDb._();
  Database? _db;
  Future<Database> get database async {
    if (_db != null) return _db!;
    final path = p.join(await getDatabasesPath(), 'amar_hisab.db');
    _db = await openDatabase(path, version: 1, onCreate: (db, v) async {
      await db.execute('CREATE TABLE customers(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, phone TEXT)');
      await db.execute('CREATE TABLE entries(id INTEGER PRIMARY KEY AUTOINCREMENT, customerId INTEGER, type TEXT NOT NULL, amount REAL NOT NULL, note TEXT, createdAt TEXT NOT NULL)');
    });
    return _db!;
  }
  Future<List<Map<String,dynamic>>> customers() async => (await database).query('customers', orderBy: 'name');
  Future<void> addCustomer(String name, String phone) async => (await database).insert('customers', {'name':name,'phone':phone});
  Future<void> addEntry(int? customerId, String type, double amount, String note) async =>
    (await database).insert('entries', {'customerId':customerId,'type':type,'amount':amount,'note':note,'createdAt':DateTime.now().toIso8601String()});
  Future<List<Map<String,dynamic>>> entries() async => (await database).rawQuery('SELECT entries.*, customers.name AS customerName FROM entries LEFT JOIN customers ON customers.id=entries.customerId ORDER BY entries.id DESC');
  Future<Map<String,double>> totals() async {
    final rows = await (await database).rawQuery("SELECT type, SUM(amount) AS total FROM entries GROUP BY type");
    final out = <String,double>{'জমা':0,'খরচ':0,'পাওনা':0};
    for (final r in rows) { out[r['type'] as String] = (r['total'] as num).toDouble(); }
    return out;
  }
}

class AmarHisabApp extends StatelessWidget {
  const AmarHisabApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner:false, title:'আমার হিসাব',
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff16845b)), useMaterial3:true, scaffoldBackgroundColor: const Color(0xfff5f7f6)),
    home: const HomePage(),
  );
}

class HomePage extends StatefulWidget { const HomePage({super.key}); @override State<HomePage> createState()=>_HomePageState(); }
class _HomePageState extends State<HomePage> {
  int tab=0; int refresh=0;
  void reload(){setState(()=>refresh++);}
  @override Widget build(BuildContext context) {
    final pages=[Dashboard(onChanged:reload,key:ValueKey('d$refresh')), CustomersPage(onChanged:reload,key:ValueKey('c$refresh')), EntriesPage(key:ValueKey('e$refresh'))];
    return Scaffold(
      appBar: AppBar(title: const Row(children:[Icon(Icons.menu_book_rounded),SizedBox(width:9),Text('আমার হিসাব',style:TextStyle(fontWeight:FontWeight.bold))]), actions:[IconButton(onPressed:reload,icon:const Icon(Icons.refresh))]),
      body: pages[tab],
      floatingActionButton: tab==1 ? FloatingActionButton.extended(onPressed:()=>showCustomerDialog(context,reload),icon:const Icon(Icons.person_add_alt_1),label:const Text('কাস্টমার যোগ')) :
        tab==2 ? FloatingActionButton.extended(onPressed:()=>showEntryDialog(context,reload),icon:const Icon(Icons.add),label:const Text('লেনদেন যোগ')) : null,
      bottomNavigationBar: NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const [
        NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'হোম'),
        NavigationDestination(icon:Icon(Icons.people_outline),selectedIcon:Icon(Icons.people),label:'কাস্টমার'),
        NavigationDestination(icon:Icon(Icons.receipt_long_outlined),selectedIcon:Icon(Icons.receipt_long),label:'লেনদেন'),
      ]),
    );
  }
}

class Dashboard extends StatelessWidget {
 final VoidCallback onChanged; const Dashboard({super.key,required this.onChanged});
 @override Widget build(BuildContext context)=>FutureBuilder(
  future:LedgerDb.instance.totals(),
  builder:(context,s){final t=s.data??{'জমা':0.0,'খরচ':0.0,'পাওনা':0.0}; final due=(t['পাওনা']??0)-(t['জমা']??0);
   return ListView(padding:const EdgeInsets.all(16),children:[
    Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xff147a55),Color(0xff26a879)]),borderRadius:BorderRadius.circular(22)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('স্বাগতম!',style:TextStyle(color:Colors.white70)),const SizedBox(height:6),const Text('আজকের হিসাব এক নজরে',style:TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.bold)),const SizedBox(height:20),
      const Text('নিট বাকি / পাওনা',style:TextStyle(color:Colors.white70)),Text(money.format(due.abs()),style:const TextStyle(color:Colors.white,fontSize:30,fontWeight:FontWeight.bold)),Text(due>=0?'আপনার পাওনা':'আপনার দেনা',style:const TextStyle(color:Colors.white))
    ])),
    const SizedBox(height:16),Wrap(spacing:12,runSpacing:12,children:[
      summaryCard('মোট জমা',t['জমা']??0,Icons.south_west,Colors.green),
      summaryCard('মোট খরচ',t['খরচ']??0,Icons.north_east,Colors.deepOrange),
      summaryCard('মোট বাকি',t['পাওনা']??0,Icons.account_balance_wallet_outlined,Colors.blue),
    ]),
    const SizedBox(height:20),const Text('দ্রুত কাজ',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),const SizedBox(height:10),
    Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.person_add_alt_1)),title:const Text('নতুন কাস্টমার যোগ করুন'),subtitle:const Text('কাস্টমারের নাম ও মোবাইল নম্বর'),trailing:const Icon(Icons.chevron_right),onTap:()=>showCustomerDialog(context,onChanged))),
    Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.add_card)),title:const Text('নতুন লেনদেন লিখুন'),subtitle:const Text('জমা, খরচ অথবা পাওনা'),trailing:const Icon(Icons.chevron_right),onTap:()=>showEntryDialog(context,onChanged))),
   ]);
  });
}
Widget summaryCard(String title,double amount,IconData icon,Color color)=>SizedBox(width: (WidgetsBinding.instance.platformDispatcher.views.first.physicalSize.width/WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio-44)/2,child:Card(child:Padding(padding:const EdgeInsets.all(15),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:color),const SizedBox(height:12),Text(title,style:const TextStyle(color:Colors.black54)),const SizedBox(height:5),Text(money.format(amount),style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold))]))));

class CustomersPage extends StatelessWidget {
 final VoidCallback onChanged; const CustomersPage({super.key,required this.onChanged});
 @override Widget build(BuildContext context)=>FutureBuilder(future:LedgerDb.instance.customers(),builder:(c,s){
  final rows=s.data??[];
  if(rows.isEmpty)return const Center(child:Text('এখনো কোনো কাস্টমার যোগ করা হয়নি'));
  return ListView.builder(padding:const EdgeInsets.all(12),itemCount:rows.length,itemBuilder:(c,i){final r=rows[i];return Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.person)),title:Text(r['name']),subtitle:Text((r['phone']??'ফোন নম্বর নেই').toString()),));});
 });
}

class EntriesPage extends StatelessWidget {
 const EntriesPage({super.key});
 @override Widget build(BuildContext context)=>FutureBuilder(future:LedgerDb.instance.entries(),builder:(c,s){
  final rows=s.data??[];
  if(rows.isEmpty)return const Center(child:Text('এখনো কোনো লেনদেন নেই'));
  return ListView.builder(padding:const EdgeInsets.all(12),itemCount:rows.length,itemBuilder:(c,i){final r=rows[i];final type=r['type'];final color=type=='জমা'?Colors.green:type=='খরচ'?Colors.deepOrange:Colors.blue;return Card(child:ListTile(leading:CircleAvatar(backgroundColor:color.withOpacity(.12),child:Icon(type=='জমা'?Icons.south_west:type=='খরচ'?Icons.north_east:Icons.schedule,color:color)),title:Text('${r['customerName']??'সাধারণ হিসাব'} • $type'),subtitle:Text('${r['note']??''}\n${DateFormat('dd-MM-yyyy  hh:mm a').format(DateTime.parse(r['createdAt']))}'),isThreeLine:true,trailing:Text(money.format((r['amount'] as num).toDouble()),style:TextStyle(color:color,fontWeight:FontWeight.bold))));});
 });
}

Future<void> showCustomerDialog(BuildContext context,VoidCallback done) async {
 final n=TextEditingController(),p=TextEditingController();
 await showDialog(context:context,builder:(c)=>AlertDialog(title:const Text('নতুন কাস্টমার'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:n,decoration:const InputDecoration(labelText:'কাস্টমারের নাম')),TextField(controller:p,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'মোবাইল নম্বর'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('বাতিল')),FilledButton(onPressed:()async{if(n.text.trim().isEmpty)return;await LedgerDb.instance.addCustomer(n.text.trim(),p.text.trim());if(c.mounted)Navigator.pop(c);done();},child:const Text('সংরক্ষণ'))]));
}
Future<void> showEntryDialog(BuildContext context,VoidCallback done) async {
 final amount=TextEditingController(),note=TextEditingController();String type='জমা';int? customerId;
 final customers=await LedgerDb.instance.customers();
 if(!context.mounted)return;
 await showDialog(context:context,builder:(c)=>StatefulBuilder(builder:(c,set)=>AlertDialog(title:const Text('নতুন লেনদেন'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
  DropdownButtonFormField<String>(value:type,decoration:const InputDecoration(labelText:'লেনদেনের ধরন'),items:['জমা','খরচ','পাওনা'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v)=>set(()=>type=v??'জমা')),
  const SizedBox(height:8),DropdownButtonFormField<int?>(value:customerId,decoration:const InputDecoration(labelText:'কাস্টমার (ঐচ্ছিক)'),items:[const DropdownMenuItem<int?>(value:null,child:Text('সাধারণ হিসাব')), ...customers.map((r)=>DropdownMenuItem<int?>(value:r['id'] as int,child:Text(r['name'])))],onChanged:(v)=>set(()=>customerId=v)),
  TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'টাকার পরিমাণ',prefixText:'৳ ')),
  TextField(controller:note,decoration:const InputDecoration(labelText:'বিবরণ (ঐচ্ছিক)')),
 ])),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('বাতিল')),FilledButton(onPressed:()async{final a=double.tryParse(amount.text.trim());if(a==null||a<=0)return;await LedgerDb.instance.addEntry(customerId,type,a,note.text.trim());if(c.mounted)Navigator.pop(c);done();},child:const Text('সংরক্ষণ'))])));
}
