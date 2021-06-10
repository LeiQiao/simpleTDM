# simpleTDM

a usful tool to use your iMac as a display with [*Target Display Mode*] https://support.apple.com/en-us/HT204592

before use this tool you will need:
1. an Apple Magic Keyboard (do not bother to find a way using PC keyboard or virtual keyboard, it is a dead end :)
2. pair this keyboard to both ends (iMac & any computer you want as a host MacBook, Air etc.)
3. a thunderbolt or Mini DisplayPort cable (for more detail please read the link at the beginning of this document)
4. keep iMac and your host in the same network

# usage
1. Download & run this tool to iMac and your host computer, when the first run in
2. Plugin the Thunderbolt or Mini DisplayPort cable an wait for entering TDM (it will take few seconds to build the connection)
3. Unplug the Thunderbolt or Mini DisplayPort to leave TDM
4. When you get into TDM your keyboard

When the first time to run this tool, it will ask you to change port, please setup the same port number in both ends.
When you get into TDM, your keyboard will reconnect to the host computer automaticlly, and you can choose to give back the keybord to iMac when you leave TDM.

# compiling
1. pod install
2. open Xcode & run

thanks [virtualKVM] https://github.com/duanefields/VirtualKVM

ps:
I only have an iMac early 2014, wich is only support Thunderbolt to Thunderbolt, and feel free to report bugs.

# ==!!! importent !!!==

you can **NOT** use a virtual keyboard or PC keyboard to enter TDM, you **MUST** have mac magic keyboard to use it. this app can easy to transport your magic keyboard between iMac and Macbook.