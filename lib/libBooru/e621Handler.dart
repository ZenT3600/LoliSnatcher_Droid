import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'dart:async';
import 'dart:convert';
import 'BooruHandler.dart';
import 'BooruItem.dart';

class e621Handler extends BooruHandler{
  List<BooruItem> fetched = new List();
  e621Handler(String baseURL,int limit) : super(baseURL,limit);

  /**
   * This function will call a http get request using the tags and pagenumber parsed to it
   * it will then create a list of booruItems
   */
  Future Search(String tags,int pageNum) async{
    this.pageNum = pageNum;
    if (prevTags != tags){
      fetched = new List();
    }
    String url = makeURL(tags);
    print(url);
    try {
      final response = await http.get(url,headers: {"Accept": "text/html,application/xml", "user-agent":"LoliSnatcher/1.1"});
      // 200 is the success http response code
      if (response.statusCode == 200) {
        Map<String, dynamic> parsedResponse = jsonDecode(response.body);
        /**
         * This creates a list of xml elements 'post' to extract only the post elements which contain
         * all the data needed about each image
         */
        var posts = parsedResponse['posts'];
        print("e621Handler::search ${parsedResponse['posts'].length}");

        // Create a BooruItem for each post in the list
        for (int i =0; i < parsedResponse['posts'].length; i++){
          var current = parsedResponse['posts'][i];
          print(current['file']['url']);
          /**
           * Add a new booruitem to the list .getAttribute will get the data assigned to a particular tag in the xml object
           */
          fetched.add(new BooruItem(current['file']['url'],current['sample']['url'],current['preview']['url'],current['tags']['general'] + current['tags']['species'] + current['tags']['character'] + current['tags']['artist'] + current['tags']['meta'],makePostURL(current['id'].toString())));
        }
        prevTags = tags;
        return fetched;
      }
    } catch(e) {
      print(e);
      return fetched;
    }

  }
  // This will create a url to goto the images page in the browser
  String makePostURL(String id){
    return "$baseURL/posts/$id?";
  }
  // This will create a url for the http request
  String makeURL(String tags){
    return "$baseURL/posts.json?tags=$tags&limit=${limit.toString()}&page=${pageNum.toString()}";
  }
}

