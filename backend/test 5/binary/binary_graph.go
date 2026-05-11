package binary

import (
	"bufio"
	"encoding/binary"
	"os"
	"test/graph"
)

func writeBinaryGraph(
	path string,
	latE7 []int32,
	lonE7 []int32,
	offset []uint32,
	to_csr []uint32,
	weight_csr []uint32,
	way_id_csr []int64,
) error {

	file, err := os.Create(path)
	if err != nil {
		return err
	}
	defer file.Close()

	writer := bufio.NewWriter(file)
	defer writer.Flush()

	nodes := uint32(len(latE7))
	edges := uint32(len(to_csr))

	if err := binary.Write(writer, binary.LittleEndian, nodes); err != nil {
		return err
	}
	if err := binary.Write(writer, binary.LittleEndian, edges); err != nil {
		return err
	}
	if err := binary.Write(writer, binary.LittleEndian, latE7); err != nil {
		return err
	}
	if err := binary.Write(writer, binary.LittleEndian, lonE7); err != nil {
		return err
	}
	if err := binary.Write(writer, binary.LittleEndian, offset); err != nil {
		return err
	}
	if err := binary.Write(writer, binary.LittleEndian, to_csr); err != nil {
		return err
	}
	if err := binary.Write(writer, binary.LittleEndian, weight_csr); err != nil {
		return err
	}
	if err := binary.Write(writer, binary.LittleEndian, way_id_csr); err != nil {
		return err
	}

	return nil
}

func readBinaryGraph(path string) ([]int32, []int32, []uint32, []uint32, []uint32, []int64, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, nil, nil, nil, nil, nil, err
	}
	defer file.Close()

	reader := bufio.NewReader(file)

	var nodes uint32
	var edges uint32

	if err := binary.Read(reader, binary.LittleEndian, &nodes); err != nil {
		return nil, nil, nil, nil, nil, nil, err
	}
	if err := binary.Read(reader, binary.LittleEndian, &edges); err != nil {
		return nil, nil, nil, nil, nil, nil, err
	}

	latE7 := make([]int32, nodes)
	lonE7 := make([]int32, nodes)
	offset := make([]uint32, nodes+1)
	to_csr := make([]uint32, edges)
	weight_csr := make([]uint32, edges)
	way_ids_csr := make([]int64, edges)

	if err := binary.Read(reader, binary.LittleEndian, latE7); err != nil {
		return nil, nil, nil, nil, nil, nil, err
	}
	if err := binary.Read(reader, binary.LittleEndian, lonE7); err != nil {
		return nil, nil, nil, nil, nil, nil, err
	}
	if err := binary.Read(reader, binary.LittleEndian, offset); err != nil {
		return nil, nil, nil, nil, nil, nil, err
	}
	if err := binary.Read(reader, binary.LittleEndian, to_csr); err != nil {
		return nil, nil, nil, nil, nil, nil, err
	}
	if err := binary.Read(reader, binary.LittleEndian, weight_csr); err != nil {
		return nil, nil, nil, nil, nil, nil, err
	}
	if err := binary.Read(reader, binary.LittleEndian, way_ids_csr); err != nil {
		return nil, nil, nil, nil, nil, nil, err
	}

	return latE7, lonE7, offset, to_csr, weight_csr, way_ids_csr, nil
}

func LoadGraph(path string) (*graph.Graph, error) {
	latE7, lonE7, offset, to_csr, weight_csr, way_ids_csr, err := readBinaryGraph(path)
	if err != nil {
		return nil, err
	}

	g := &graph.Graph{
		LatE7:      latE7,
		LonE7:      lonE7,
		Offset:     offset,
		To_csr:     to_csr,
		Weight_csr: weight_csr,
		WayID_csr:  way_ids_csr,
	}

	return g, nil
}

func SaveGraph(path string, g *graph.Graph) error {
	return writeBinaryGraph(
		path,
		g.LatE7,
		g.LonE7,
		g.Offset,
		g.To_csr,
		g.Weight_csr,
		g.WayID_csr,
	)
}
