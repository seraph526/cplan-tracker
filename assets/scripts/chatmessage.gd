extends Control

var msg_count = 0;
var max_msg = 5;

func add_msg(text):
	if msg_count < max_msg:
		msg_count += 1;
		var node = get_node("line"+str(msg_count));
		node.get_node("msg").set_text(text);
		node.show();
	else:
		for i in range(1, msg_count):
			var node = get_node("line"+str(i));
			var node1 = get_node("line"+str(i+1));
			node.get_node("msg").set_text(node1.get_node("msg").get_text());
		
		var node = get_node("line"+str(msg_count));
		node.get_node("msg").set_text(text);