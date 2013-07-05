/*
 Generic queue.
 */

@interface NSMutableArray (QueueAdditions) 
-(id) NSMADequeue;
-(void) NSMAEnqueue:(id)obj;
-(id) NSMAPeek:(int)index;
-(id) NSMAPeekHead;
-(id) NSMAPeekTail;
-(BOOL) NSMAEmpty;
@end