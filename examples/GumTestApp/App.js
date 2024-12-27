/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 * @flow strict-local
 */

import React, {useState, useRef, useEffect} from 'react';
import {
  Button,
  SafeAreaView,
  StyleSheet,
  View,
  StatusBar,
} from 'react-native';
import { Colors } from 'react-native/Libraries/NewAppScreen';
import { mediaDevices, startIOSPIP, stopIOSPIP, RTCPIPView } from 'react-native-webrtc';


const App = () => {
  const view = useRef()
  const [stream, setStream] = useState(null);
  const [pip, setPip] = useState(false);
  const [content, setContent] = useState(0);

  useEffect(() => {
    const inteval = setInterval(() => {
      setContent(pre=> pre + 1);
    }, 1000);
    return () => {
     clearInterval(inteval);
    }
  },[]);
  const start = async () => {
    console.log('start');
    
    if (!stream) {
      try {
        const s = await mediaDevices.getUserMedia({ video: true });
        setStream(s);
      } catch(e) {
        console.error(e);
      }
    }
  };
  const startPIP = () => {
    setPip(true);
    startIOSPIP(view);
  };
  const stopPIP = () => {
    setPip(false);
    stopIOSPIP(view);
  };
  const stop = () => {
    console.log('stop');
    if (stream) {
      stream.release();
      setStream(null);
    }
  };
  let pipOptions = {
    startAutomatically: true,
    preferredSize: {
      width: 200,
      height: 400,
    },
    extraOptions: {
      title: `title`,
      // description: 'description',
      content: `${content}`,
    },
  }
  let url =stream?.toURL();
  // if(pip){
  //   url = undefined;
  // }
  return (
    <>
      <StatusBar barStyle="dark-content" />
      <SafeAreaView style={styles.body}>
      {
        stream &&
        <RTCPIPView
            ref={view}
            mirror={true}
            streamURL={url}
            style={styles.stream}
            iosPIP={pipOptions} >
        </RTCPIPView>
      }
        <View
          style={styles.footer}>
          <Button
            title = "Start"
            onPress = {start} />
          <Button
            title = "Start PIP"
            onPress = {startPIP} />
          <Button
            title = "Stop PIP"
            onPress = {stopPIP} />
          <Button
            title = "Stop"
            onPress = {stop} />
        </View>
      </SafeAreaView>
    </>
  );
};

const styles = StyleSheet.create({
  body: {
    backgroundColor: Colors.white,
    ...StyleSheet.absoluteFill
  },
  stream: {
    flex: 1
  },
  footer: {
    backgroundColor: Colors.lighter,
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0
  },
});

export default App;
