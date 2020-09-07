import 'dart:collection';
import 'dart:io';
import 'package:hash/hash.dart';

extension FileExtension on FileSystemEntity {
  String get name {
    return this?.path?.split("/")?.last;
  }
}

class SourceAndDuplicates {
  File source;
  int size;
  DateTime changed;
  List<File> duplicates;
  SourceAndDuplicates(File source, FileStat stat) {
    this.source = source;
    duplicates = List();
    changed = stat.changed;
    size = stat.size;
  }
  addFile(File file, FileStat stat) {
    if (stat.changed.isBefore(changed)) {
      duplicates.add(source);
      source = file;
      changed = stat.changed;
    } else
      duplicates.add(file);
  }
}

class DuplicateContainer implements Comparable<DuplicateContainer> {
  String name;
  int sizeOfDuplicates;
  DuplicateContainer({this.name, this.sizeOfDuplicates});
  int compareTo(DuplicateContainer b) {
    if (this.name == b.name) return 0;
    if (this.sizeOfDuplicates > b.sizeOfDuplicates) return 1;
    if (this.sizeOfDuplicates < b.sizeOfDuplicates) return -1;
    return this.name.compareTo(b.name);
  }
}

class DuplicateFile extends DuplicateContainer {
  String source;
  String absolutePath;
  DuplicateFile({name, this.source, this.absolutePath, sizeOfDuplicates})
      : super(name: name, sizeOfDuplicates: sizeOfDuplicates);
}

class DuplicateParentFolder extends DuplicateContainer {
  Set<DuplicateContainer> children = SplayTreeSet();
  DuplicateParentFolder({name, sizeOfDuplicates})
      : super(name: name, sizeOfDuplicates: sizeOfDuplicates);
}

class DuplicateFinder {
  Directory directory;
  DuplicateParentFolder duplicateParentFolder;
  Map<String, SourceAndDuplicates> files;

  DuplicateFinder(Directory directory) {
    this.directory = directory;
    this.duplicateParentFolder =
        DuplicateParentFolder(name: directory.name, sizeOfDuplicates: 0);
    files = Map();
  }

  findDuplicates() async {
    await for (FileSystemEntity entity
        in directory.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        File file = entity;
        var hash = MD5();
        await file.openRead().listen(hash.update).asFuture();
        String digest = "";
        hash
            .digest()
            .forEach((int byte) => digest += String.fromCharCode(byte));

        FileStat stat = file.statSync();
        if (files.containsKey(digest))
          await files[digest].addFile(file, stat);
        else
          files[digest] = SourceAndDuplicates(file, stat);
      }
    }
  }

  processDuplicates() {
    files
      ..removeWhere((key, value) => value.duplicates.length == 0)
      ..values.forEach((element) {
        duplicateParentFolder.sizeOfDuplicates +=
            element.duplicates.length * element.size;
        for (File duplicate in element.duplicates) {
          String relative = duplicate.path.substring(directory.path.length + 1);
          DuplicateParentFolder parentFolder = duplicateParentFolder;
          List<String> parts = relative.split("/");
          String filename = parts.removeLast();
          for (String part in parts) {
            DuplicateParentFolder newParentFolder = DuplicateParentFolder(
                name: part, sizeOfDuplicates: element.size);
            if (parentFolder.children.contains(newParentFolder)) {
              newParentFolder = parentFolder.children.lookup(newParentFolder);
              newParentFolder.sizeOfDuplicates += element.size;
            } else
              parentFolder.children.add(newParentFolder);
            parentFolder = newParentFolder;
          }
          parentFolder.children.add(DuplicateFile(
              name: filename,
              source: element.source.absolute.path,
              absolutePath: duplicate.absolute.path,
              sizeOfDuplicates: element.size));
        }
      });
  }

  findAndProcessDuplicates() async {
    await findDuplicates();
    processDuplicates();
  }
}
