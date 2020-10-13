import 'package:flutter/material.dart';
import 'package:file_chooser/file_chooser.dart';
import 'dart:io';
import 'duplicate_finder.dart';
import 'tree_view.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const String title = 'Dedupe It';
    return MaterialApp(
      title: title,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: title),
    );
  }
}

class DuplicateContainerWidgetProps {
  DuplicateContainer duplicateContainer;
  int totalDuplicateSize;
  int parentDuplicateSize;
  String absolutePath;
  bool showActions = false;
  bool showInfo = false;
  DuplicateContainerWidgetProps(
      {this.duplicateContainer,
      this.totalDuplicateSize,
      this.parentDuplicateSize,
      this.absolutePath,
      this.showActions,
      this.showInfo});
}

class DuplicateContainerWidget extends StatefulWidget {
  static _DuplicateContainerWidgetState of(BuildContext context) =>
      context.findAncestorStateOfType<_DuplicateContainerWidgetState>();
  final DuplicateContainerWidgetProps props;
  _DuplicateContainerWidgetState state;
  DuplicateContainerWidget({Key key, this.props})
      : super(key: key == null ? UniqueKey() : key);
  @override
  _DuplicateContainerWidgetState createState() {
    state = _DuplicateContainerWidgetState(props: props);
    return state;
  }

  static buildTree(DuplicateContainerWidgetProps props) {
    DuplicateContainerWidget duplicateContainerWidget =
        DuplicateContainerWidget(props: props);
    DuplicateContainer duplicateContainer = props.duplicateContainer;
    if (duplicateContainer is DuplicateParentFolder) {
      return TreeView(
          child: duplicateContainerWidget,
          collapsed:
              props.showInfo ? false : duplicateContainer.children.length > 1,
          subChildren: [
            for (DuplicateContainer container in duplicateContainer.children)
              buildTree(DuplicateContainerWidgetProps(
                  duplicateContainer: container,
                  totalDuplicateSize: props.totalDuplicateSize,
                  parentDuplicateSize: duplicateContainer.sizeOfDuplicates,
                  absolutePath: props.absolutePath + '/' + container.name,
                  showActions: duplicateContainer.children.length > 1,
                  showInfo: false))
          ]);
    }
    return duplicateContainerWidget;
  }
}

class _DuplicateContainerWidgetState extends State<DuplicateContainerWidget> {
  DuplicateContainerWidgetProps props;

  _DuplicateContainerWidgetState({this.props});

  get duplicateContainer {
    return props.duplicateContainer;
  }

  get totalDuplicateSize {
    return props.totalDuplicateSize;
  }

  get parentDuplicateSize {
    return props.parentDuplicateSize;
  }

  _formatPercentage(int flooredPercentage) {
    return (flooredPercentage == 0
            ? 'less than 1'
            : flooredPercentage.toString()) +
        ' %';
  }

  _formatSize() {
    int size = duplicateContainer.sizeOfDuplicates;
    const sizes = ['', 'K', 'M', 'G'];
    int index = 0;
    double sizeHighest = size.toDouble() * 8;
    while (sizeHighest >= 1024 && index < sizes.length) {
      sizeHighest /= 1024;
      index++;
    }
    String formatted = sizeHighest.toStringAsFixed(2);
    if (formatted.endsWith('.00'))
      formatted = formatted.substring(0, formatted.length - 3);
    size *= 100;
    int absPercentage = (size / totalDuplicateSize).floor();
    return Text(
      formatted +
          ' ' +
          sizes[index] +
          'B - ' +
          _formatPercentage(absPercentage) +
          (props.parentDuplicateSize == totalDuplicateSize
              ? ''
              : ' - ' +
                  _formatPercentage((size / parentDuplicateSize).floor())),
      style: TextStyle(color: Colors.grey),
    );
  }

  _removeFromTreeView(TreeViewState parent, Widget widget) {
    parent.setState(() {
      parent.widget.subChildren.remove(widget);
      if (parent.widget.subChildren.length == 1) {
        StatefulWidget onlyChildOrParent = parent.widget.subChildren[0];
        DuplicateContainerWidget onlyChild;
        if (onlyChildOrParent is TreeView)
          onlyChild = onlyChildOrParent.child;
        else
          onlyChild = onlyChildOrParent;
        onlyChild.state.setState(() => onlyChild.props.showActions = false);
      }
    });
  }

  _remove(BuildContext context, Widget widget) {
    TreeViewState parent = context.findAncestorStateOfType<TreeViewState>();
    if (duplicateContainer is DuplicateParentFolder) {
      TreeViewState parentParent =
          parent.context.findAncestorStateOfType<TreeViewState>();
      if (parentParent == null) {
        _MyHomePageState homePage =
            parent.context.findAncestorStateOfType<_MyHomePageState>();
        homePage.setState(() {
          homePage.duplicateFinder = null;
        });
      } else
        _removeFromTreeView(parentParent, parent.widget);
    } else
      _removeFromTreeView(parent, widget);
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [
      if (!(duplicateContainer is DuplicateParentFolder))
        Container(padding: EdgeInsets.all(8), child: Icon(Icons.copy)),
      Text(duplicateContainer.name)
    ];

    var remove = () => _remove(context, widget);

    link(DuplicateContainer container) {
      if (container is DuplicateParentFolder) {
        for (DuplicateContainer child in container.children) link(child);
      } else if (container is DuplicateFile)
        File(container.absolutePath).delete().then((FileSystemEntity fes) {
          Link(container.absolutePath)
              .create(container.source)
              .catchError((error) {
            print(error); // TODO
          });
        });
    }

    delete(DuplicateContainer container) {
      if (container is DuplicateParentFolder) {
        for (DuplicateContainer child in container.children) delete(child);
      } else
        File((container as DuplicateFile).absolutePath)
            .delete()
            .catchError((error) {
          print(error); // TODO
        });
    }

    const double splashRadius = 20;
    if (props.showActions)
      children.addAll(<Widget>[
        IconButton(
          icon: Icon(Icons.info),
          color: Colors.cyan,
          splashRadius: splashRadius,
          tooltip: 'Info',
          onPressed: () {
            setState(() {
              props.showInfo = !props.showInfo;
            });
          },
        ),
        if (props.showInfo)
          Container(
              margin: EdgeInsets.only(left: 5, right: 5), child: _formatSize()),
        IconButton(
          icon: Icon(Icons.check),
          splashRadius: splashRadius,
          color: Colors.green,
          tooltip: 'Done',
          onPressed: remove,
        ),
        IconButton(
          icon: Icon(Icons.link),
          splashRadius: splashRadius,
          color: Colors.amber,
          tooltip: 'Link',
          onPressed: () {
            link(props.duplicateContainer);
            remove();
          },
        ),
        IconButton(
          icon: Icon(Icons.delete),
          splashRadius: splashRadius,
          color: Colors.red,
          tooltip: 'Delete',
          onPressed: () {
            delete(props.duplicateContainer);
            remove();
          },
        )
      ]);
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: children,
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  DuplicateFinder duplicateFinder;
  bool showInfo = false;
  bool searching = false;

  get totalDuplicateSize {
    return duplicateFinder.duplicateParentFolder.sizeOfDuplicates;
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    TextStyle lead = Theme.of(context).textTheme.headline4;
    leadIcon(IconData data) =>
        Icon(data, size: lead.fontSize, color: lead.color);
    leadingText(Widget icon, String text) => Center(
        child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [icon, Text(' ' + text, style: lead)]));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Scrollbar(
        child: duplicateFinder == null
            ? leadingText(leadIcon(Icons.search), 'Search for duplicates')
            : (searching
                ? leadingText(
                    SpinKitCircle(
                      color: lead.color,
                      size: lead.fontSize,
                      controller: AnimationController(
                          vsync: this,
                          duration: const Duration(milliseconds: 1200)),
                    ),
                    'Searching duplicates…')
                : (duplicateFinder.duplicateParentFolder.sizeOfDuplicates == 0
                    ? leadingText(leadIcon(Icons.check), 'No duplicates found')
                    : ListView(
                        children: [
                          if (duplicateFinder != null)
                            DuplicateContainerWidget.buildTree(
                                DuplicateContainerWidgetProps(
                                    duplicateContainer:
                                        duplicateFinder.duplicateParentFolder,
                                    totalDuplicateSize: duplicateFinder
                                        .duplicateParentFolder.sizeOfDuplicates,
                                    parentDuplicateSize: duplicateFinder
                                        .duplicateParentFolder.sizeOfDuplicates,
                                    absolutePath:
                                        duplicateFinder.directory.absolute.path,
                                    showActions: true,
                                    showInfo: true)),
                        ],
                      ))),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (searching) {
            duplicateFinder.cancel();
            setState(() {
              duplicateFinder = null;
              searching = false;
            });
            return;
          }
          showOpenPanel(
            initialDirectory: '',
            allowsMultipleSelection: false,
            canSelectDirectories: true,
            confirmButtonText: 'Search duplicates',
          ).then((FileChooserResult value) async {
            if (value.canceled) return;
            setState(() {
              searching = true;
            });
            duplicateFinder = DuplicateFinder(new Directory(value.paths[0]));
            await duplicateFinder.findAndProcessDuplicates();
            if (duplicateFinder == null || duplicateFinder.cancelled) return;
            setState(() {
              searching = false;
            });
          });
        },
        backgroundColor: searching ? Colors.red : theme.accentColor,
        tooltip: searching ? 'Cancel' : 'Find Duplicates',
        child: Icon(searching ? Icons.close : Icons.search),
      ),
    );
  }
}
