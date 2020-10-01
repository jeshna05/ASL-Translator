import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io' as Io;
import 'dart:developer';
import 'main.dart';
import 'package:http/http.dart' as http;

String label = 'NULL';
double detectedConf = -1;

// A screen that allows users to take a picture using a given camera.
class TakePictureScreen extends StatefulWidget {
  final CameraDescription camera;

  const TakePictureScreen({
    Key key,
    @required this.camera,
  }) : super(key: key);

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  CameraController _controller;
  Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    // To display the current output from the Camera,
    // create a CameraController.
    _controller = CameraController(
      // Get a specific camera from the list of available cameras.
      widget.camera,
      // Define the resolution to use.
      ResolutionPreset.medium,
    );

    // Next, initialize the controller. This returns a Future.
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Take a picture')),
      // Wait until the controller is initialized before displaying the
      // camera preview. Use a FutureBuilder to display a loading spinner
      // until the controller has finished initializing.
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // If the Future is complete, display the preview.
            return CameraPreview(_controller);
          } else {
            // Otherwise, display a loading indicator.
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.camera_alt),
        // Provide an onPressed callback.
        onPressed: () async {
          // Take the Picture in a try / catch block. If anything goes wrong,
          // catch the error.
          try {
            // Ensure that the camera is initialized.
            await _initializeControllerFuture;


            // Construct the path where the image should be saved using the
            // pattern package.
            final path = join(
              // Store the picture in the temp directory.
              // Find the temp directory using the `path_provider` plugin.
              (await getTemporaryDirectory()).path,
              '${DateTime.now()}.png',
            );

            // Attempt to take a picture and log where it's been saved.
            await _controller.takePicture(path);

            // If the picture was taken, display it on a new screen.
            label = await getImageLabel(path);

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DisplayPictureScreen(imagePath: path),
              ),
            );
          } catch (e) {
            // If an error occurs, log the error to the console.
            print(e);
          }
        },
      ),
    );
  }
}

// A widget that displays the picture taken by the user.
class DisplayPictureScreen extends StatelessWidget {
  final String imagePath;

  const DisplayPictureScreen({Key key, this.imagePath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      // The image is stored as a file on the device. Use the `Image.file`
      // constructor with the given path to display the image.
      body: Image.file(File(imagePath)),
    );
  }
}

//makes request to API
Future<detection> detectIt(String imgBytes) async {
  final http.Response resp = await http.post(
    "https://nuu3hmin2b.execute-api.us-east-2.amazonaws.com/v1/detect",
    headers: <String, String>{
      "Content-Type": "application/x-amz-json-1.1",
      "X-Amz-Target": "RekognitionService.DetectCustomLabels"
    },
    body: jsonEncode(<String, dynamic>{
      "Image": {"Bytes": imgBytes},
      "MaxResults": maxResult,
      "MinConfidence": conf,
      "ProjectVersionArn": pv_arn
    }),
  );

  if (resp.statusCode == 200)
  {
    print ("success");
    print("\nResponse Body\n:::::\n"+resp.body+"\n:::::\n");
    detection result = new detection(json.decode(resp.body));
    return  result;
  }
  else
  {
    throw Exception('Failed. Status code: ' + resp.statusCode.toString() + "\nResponse Body: " + resp.body+"\n\n");
  }
}

Future<String> getImageLabel(String imagePath) async{
  // log(imagePath);
  // Image img = Image.file(File(imagePath));
  final bytes = await Io.File(imagePath).readAsBytes();
  // String base64Encode(List<int> bytes) => base64.encode(bytes)
  String base64Encode = base64.encode(bytes);
  //log(base64Encode);
  detection resp = await detectIt(base64Encode);
  String detectedLabel = resp.getLabel();
  log(detectedLabel);
  return detectedLabel;
}
class detection {
  double confidence;
  String label;

  //constructor
  detection(Map<String, dynamic> json){
    this.confidence = json['CustomLabels'][0]['Confidence'];
    this.label = json['CustomLabels'][0]['Name'];
  }

  double getConf(){
    return this.confidence;
  }

  String getLabel(){
    return this.label;
  }

  String toString(){
    return "Response Test";
  }
}
