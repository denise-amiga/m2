#pragma once

int open_device(void);
void init_device(void);
void uninit_device(void);
int close_device(void);
void stop_capturing(void);
void start_capturing(void);
int readFrame(void);

extern int frame_number;
extern void *frame_data;
extern int frame_size;
extern int frame_type;
