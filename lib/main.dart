import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

void main(List<String> args) {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'PDF处理'),
      builder: EasyLoading.init(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class Page {
  Uint8List image;
  bool checked;
  int pageNum;

  Page(this.image, this.checked, this.pageNum);
}

class _MyHomePageState extends State<MyHomePage> {
  final List<Page> _list = [];
  bool _dragging = false;
  ImageProvider<Object>? preview;

  Future<List<Page>> loadPdf(XFile file) async {
    List<Page> list = [];
    var filename = file.name.toLowerCase();
    if (filename.endsWith(".jpg") ||
        filename.endsWith(".bmp") ||
        filename.endsWith(".tiff") ||
        filename.endsWith(".png")) {
      list.add(Page(await file.readAsBytes(), true, 1));
      return list;
    } else {
      var b = await file.readAsBytes();
      int i = 1;
      await for (var page in Printing.raster(b)) {
        var x = i;
        var png = await page.toPng();
        list.add(Page(png, true, x));
        i++;
      }
      return list;
    }
  }

  void save() async {
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Please select an output file:',
      fileName: 'output-file.pdf',
    );

    if (outputFile != null) {
      EasyLoading.show(status: 'saving...');
      final pdf = pw.Document();
      for (var img in _list) {
        if (img.checked) {
          pdf.addPage(pw.Page(build: (pw.Context context) {
            return pw.Image(pw.MemoryImage(img.image));
          }));
        }
      }
      final file = File(outputFile);
      await file.writeAsBytes(await pdf.save());
      EasyLoading.dismiss();
    }
  }

  void _handlePreview(ImageProvider<Object> image) {
    setState(() {
      preview = image;
    });
  }

  void _handleClosePreview() {
    setState(() {
      preview = null;
    });
  }

  void _handleCleanList() {
    setState(() {
      _list.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    DropTarget droper = DropTarget(
      onDragDone: (detail) async {
        EasyLoading.show(status: 'LOADING...');
        for (var file in detail.files) {
          List<Page> pages = await loadPdf(file);
          _list.addAll(pages);
        }
        EasyLoading.dismiss();
        setState(() {});
      },
      onDragEntered: (detail) {
        setState(() {
          _dragging = true;
        });
      },
      onDragExited: (detail) {
        setState(() {
          _dragging = false;
        });
      },
      child: const Image(
          height: 28, width: 50, image: AssetImage('graphics/upload.jpg')),
    );

    int i = 0;
    List<Widget> list = [];
    for (Page item in _list) {
      var x = i;
      var image = MemoryImage(item.image);
      list.add(Column(children: [
        InkWell(
            onTap: () {
              _handlePreview(image);
            },
            child: Ink.image(image: image, height: 200, width: 150)),
        SizedBox(
            width: 150,
            child: Row(
              children: [
                Checkbox(
                  value: _list[x].checked,
                  onChanged: (value) {
                    setState(() {
                      _list[x].checked = value!;
                    });
                  },
                ),
                Text(_list[x].pageNum.toString())
              ],
            )),
      ]));
      i++;
    }
    Widget child;
    if (preview == null) {
      child = Column(
        children: [
          Row(children: [
            droper,
            ElevatedButton(
                onPressed: _handleCleanList, child: const Text("DELETE")),
            ElevatedButton(onPressed: save, child: const Text("EXPORT")),
          ]),
          Expanded(
              child: SizedBox(
                  width: double.infinity,
                  child: SingleChildScrollView(
                      child: Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: list,
                  )))),
        ],
      );
    } else {
      child = InkWell(
          onTap: _handleClosePreview, child: Ink.image(image: preview!));
    }

    return child;
  }
}
