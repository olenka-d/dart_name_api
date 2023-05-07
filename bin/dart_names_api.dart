import 'dart:async';
import 'dart:convert';
import 'package:untitled_dart/dart_names_api.dart' as dart_names_api;
import 'package:sqlite3/sqlite3.dart';
import 'dart:io';

class Databases {
  late Database database;
  List<Map<String, Object?>>? result;

  Future<void> openDatabase() async {
    final dbFile = File('Names_db.db');
    database = sqlite3.open(dbFile.path);
    database.execute("CREATE TABLE IF NOT EXISTS Names (count INT, gender VARCHAR(20), name VARCHAR(20) PRIMARY KEY ON CONFLICT REPLACE, probability REAL)");
  }

  Future<void> insertData(Names names) async {
    database.execute("INSERT INTO Names VALUES(${names.count}, '${names.gender}', '${names.name}', '${names.probability}'); ");
  }

  Future<void> readData() async {
    result = await database.select('SELECT * FROM NAMES');
    for (final row in result!) {
      print('count: ${row['count']}, gender: ${row['gender']}, name: ${row['name']}, probability: ${row['probability']}');
    }
  }

  Future<void> findName(String s) async{
    final result_find = await database.select("SELECT * FROM NAMES WHERE name like '%${s}%'");
    for (final row in result_find) {
      print('count: ${row['count']}, gender: ${row['gender']}, name: ${row['name']}, probability: ${row['probability']}');
    }
  }
}

class Names {
  int? count;
  String? gender;
  String? name;
  double? probability;

  Names({this.count, this.gender, this.name, this.probability});

  Names.fromJson(Map<String, dynamic> json) {
    count = json['count'];
    gender = json['gender'];
    name = json['name'];
    probability = json['probability'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['count'] = this.count;
    data['gender'] = this.gender;
    data['name'] = this.name;
    data['probability'] = this.probability;
    return data;
  }
}

class Files {
  Future<File> createFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      print('File already exists');
    } else {
      await file.create();
    }
    return file;
  }

  Future<void> writeDataToFile(String filePath, List<Map<String, Object?>>? result) async {
    final file = File(filePath);
    final lines = result!.map((row) {
      return 'count: ${row['count']}, gender: ${row['gender']}, name: ${row['name']}, probability: ${row['probability']}';
    });
    await file.writeAsString(lines.join('\n'));
  }

  Future<String> readFile(File file) async {
    if (await file.exists()) {
      final content = await file.readAsString();
      return content;
    } else {
      throw FileSystemException('File not found');
    }
  }
}

Future<void> sendNames(String jsonDB, HttpClient http, String url) async {
  final request = await http.postUrl(Uri.parse(url))
    ..headers.contentType = ContentType.json
    ..write(jsonDB);
  final response = await request.close();
  await for (var contents in response.transform(utf8.decoder)) {
    print(contents);
  }
}

void main() async {
  final httpClient = HttpClient();
  const url = 'https://api.genderize.io?name=petro';

  final request = await httpClient.getUrl(Uri.parse(url));
  final response = await request.close();
  final responseBody = await response.transform(utf8.decoder).join();
  final jsonMap = json.decode(responseBody) as Map<String, dynamic>;
  final names = Names.fromJson(jsonMap);

  var db = new Databases();
  await db.openDatabase();
  await db.insertData(names);
  print('Print all names');
  await db.readData();
  print('Print names with condition');
  await db.findName('g');

  final filePath = 'Names.txt';
  final fileName = Files();
  final file = await fileName.createFile(filePath);
  await fileName.writeDataToFile(filePath, db.result);
  final content = await fileName.readFile(file);
  print('Print names in file');
  print(content);

  final result = await db.database.select('SELECT * FROM Names');
  final jsonDB = jsonEncode(result);
  print('Post json');
  await sendNames(jsonDB, httpClient, url);

  db.database.dispose();
}