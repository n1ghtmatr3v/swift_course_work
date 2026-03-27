package binary

import (
	"encoding/binary"
	"os"
	"test/kdtree"
)

func writeKDNode(file *os.File, node *kdtree.KDNode) error {

	if node == nil {
		var flag uint8 = 0
		return binary.Write(file, binary.LittleEndian, flag)
	}

	var flag uint8 = 1
	if err := binary.Write(file, binary.LittleEndian, flag); err != nil {
		return err
	}

	if err := binary.Write(file, binary.LittleEndian, node.Point.Vertex); err != nil {
		return err
	}

	if err := binary.Write(file, binary.LittleEndian, node.Point.X); err != nil {
		return err
	}

	if err := binary.Write(file, binary.LittleEndian, node.Point.Y); err != nil {
		return err
	}

	if err := writeKDNode(file, node.Left); err != nil {
		return err
	}

	if err := writeKDNode(file, node.Right); err != nil {
		return err
	}

	return nil
}

func SaveKDtree(root *kdtree.KDNode, path string) error {

	file, err := os.Create(path)
	if err != nil {
		return err
	}
	defer file.Close() // закрытие файла в конце

	return writeKDNode(file, root)
}

func readKDNode(file *os.File) (*kdtree.KDNode, error) {

	var flag uint8

	if err := binary.Read(file, binary.LittleEndian, &flag); err != nil {
		return nil, err
	}

	if flag == 0 {
		return nil, nil
	}

	var vertex uint32
	if err := binary.Read(file, binary.LittleEndian, &vertex); err != nil {
		return nil, err
	}

	var x int32
	if err := binary.Read(file, binary.LittleEndian, &x); err != nil {
		return nil, err
	}

	var y int32
	if err := binary.Read(file, binary.LittleEndian, &y); err != nil {
		return nil, err
	}

	node := &kdtree.KDNode{
		Point: kdtree.KDPoint{
			Vertex: vertex,
			X:      x,
			Y:      y,
		},
	}

	left, err := readKDNode(file)
	if err != nil {
		return nil, err
	}

	node.Left = left

	right, err := readKDNode(file)
	if err != nil {
		return nil, err
	}

	node.Right = right

	return node, nil
}

func LoadKDtree(path string) (*kdtree.KDNode, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	return readKDNode(file)
}
