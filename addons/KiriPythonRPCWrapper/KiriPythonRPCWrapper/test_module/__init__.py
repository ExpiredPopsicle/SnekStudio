#!/usr/bin/python3

this_is_not_a_thing_to_call = 0

def func_to_call(asdf):
    print("called with: ", asdf)
    global this_is_not_a_thing_to_call
    this_is_not_a_thing_to_call += 1
    return str(asdf) + "blah"

def other_func_to_call():
    print("jksdmckjsdncjksncs")


