// 引入标准库中的文件操作模块
use std::fs::{File, OpenOptions};
use std::io::{Read, Seek, SeekFrom, Write};

// 定义一个函数，接受四个文件名和两个偏移量作为参数
fn write_to_file(source: &str, target: &str, source_offset: usize, target_offset: u64) {
    use std::fs;
    let metadata = fs::metadata(source).unwrap();
    let file_size: usize = metadata.len().try_into().unwrap(); 
    // 定义一个常量，表示要写入的字节数量
    let BYTES_TO_WRITE: usize = file_size - source_offset;
    // 创建一个字节数组，用于存储读取的字节
    // let mut buffer = [0u8; BYTES_TO_WRITE];
    let mut buffer = vec![0; BYTES_TO_WRITE];

    // 打开源文件，只读模式
    let mut source_file = File::open(source).expect("无法打开源文件");
    // 将源文件的指针移动到指定的偏移量位置
    source_file
        .seek(SeekFrom::Start(source_offset.try_into().unwrap()))
        .expect("无法移动到指定偏移量");
    // 读取指定数量的字节到字节数组中
    source_file
        .read_exact(&mut buffer)
        .expect("无法读取指定数量的字节");

    // 打开目标文件，读写模式，如果不存在则创建
    let mut target_file = OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .open(target)
        .expect("无法打开目标文件");
    // 将目标文件的指针移动到指定的偏移量位置
    target_file
        .seek(SeekFrom::Start(target_offset))
        .expect("无法移动到指定偏移量");
    // 将字节数组的内容写入到目标文件中
    target_file
        .write_all(&buffer)
        .expect("无法写入目标文件");
    // 保存并关闭目标文件
    target_file.flush().expect("无法保存目标文件");
}


fn main() {
    // 调用函数，传入四个文件名和两个偏移量
    // 000012E0
    write_to_file("shellcode.obj", "test.exe", 0x64, 0x2A00);
}
