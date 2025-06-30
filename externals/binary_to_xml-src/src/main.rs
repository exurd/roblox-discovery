use std::io::{self, BufReader};
use rbx_binary;
use rbx_xml;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let stdin = io::stdin();
    let reader = BufReader::new(stdin.lock());
    let dom = rbx_binary::from_reader(reader)?;
    let root = dom.root();
    rbx_xml::to_writer_default(&mut io::stdout(), &dom, root.children())?;
    Ok(())
}
