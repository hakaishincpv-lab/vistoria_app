import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:signature/signature.dart';

void main() {
  runApp(const VistoriaApp());
}

/// PALETA DE CORES (da imagem enviada)
const Color primaryColor = Color(0xFF006D77); // azul petróleo
const Color secondaryColor = Color(0xFF83C5BE); // verde claro
const Color backgroundColor = Color(0xFFEDF6F9); // fundo
const Color cardColor = Color(0xFFFFDDD2); // pêssego claro
const Color accentDangerColor = Color(0xFFE29578); // laranja melancia

class VistoriaApp extends StatelessWidget {
  const VistoriaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vistoria de Alimentos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          primary: primaryColor,
          secondary: secondaryColor,
        ),
        scaffoldBackgroundColor: backgroundColor,
        useMaterial3: true,
      ),
      home: const StartScreen(),
    );
  }
}

/// ======================
/// MODELOS DE DADOS
/// ======================

class ChecklistItem {
  final String texto;
  bool? conforme; // true = Conforme, false = Não conforme, null = não avaliado
  String? observacoes;
  String? fotoPath; // caminho da foto em caso de não conformidade

  ChecklistItem({
    required this.texto,
    this.conforme,
    this.observacoes,
    this.fotoPath,
  });
}

class Categoria {
  final String titulo;
  final List<ChecklistItem> itens;

  Categoria({required this.titulo, required this.itens});
}

class VistoriaDados {
  String empresa;
  String cnpj;
  String responsavel;
  String contato;
  String email;
  DateTime dataHora;

  VistoriaDados({
    required this.empresa,
    required this.cnpj,
    required this.responsavel,
    required this.contato,
    required this.email,
    required this.dataHora,
  });
}

class VistoriaHistorico {
  final String empresa;
  final String cnpj;
  final DateTime dataHora;
  final String filePath;

  VistoriaHistorico({
    required this.empresa,
    required this.cnpj,
    required this.dataHora,
    required this.filePath,
  });

  Map<String, dynamic> toJson() => {
        'empresa': empresa,
        'cnpj': cnpj,
        'dataHora': dataHora.toIso8601String(),
        'filePath': filePath,
      };

  factory VistoriaHistorico.fromJson(Map<String, dynamic> json) {
    return VistoriaHistorico(
      empresa: json['empresa'] as String,
      cnpj: json['cnpj'] as String? ?? '',
      dataHora: DateTime.parse(json['dataHora'] as String),
      filePath: json['filePath'] as String,
    );
  }
}

class AssinaturasVistoria {
  final Uint8List responsavel;
  final Uint8List caroline;

  AssinaturasVistoria({
    required this.responsavel,
    required this.caroline,
  });
}

/// ======================
/// HELPERS
/// ======================

String _formatDate(DateTime dt) {
  final d = dt.day.toString().padLeft(2, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final y = dt.year.toString();
  return '$d/$m/$y';
}

String _formatDateTime(DateTime dt) {
  final d = dt.day.toString().padLeft(2, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final y = dt.year.toString();
  final h = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  return '$d/$m/$y $h:$min';
}

String _sanitizeFileName(String input) {
  final withoutSpaces = input.replaceAll(' ', '_');
  final regex = RegExp(r'[^a-zA-Z0-9_\-]');
  return withoutSpaces.replaceAll(regex, '');
}

/// Categorias e itens exatamente como você enviou
List<Categoria> criarCategoriasPadrao() {
  return [
    Categoria(
      titulo: '1. Estrutura Física e Instalações',
      itens: [
        ChecklistItem(texto: 'Paredes lisas, laváveis, impermeáveis e de cor clara'),
        ChecklistItem(texto: 'Teto íntegro, sem goteiras, mofo ou sujeira'),
        ChecklistItem(texto: 'Piso resistente, antiderrapante, sem rachaduras'),
        ChecklistItem(texto: 'Ralos sifonados com telas protetoras e tampas'),
        ChecklistItem(texto: 'Janelas com proteção contra insetos'),
        ChecklistItem(texto: 'Iluminação adequada e protegida'),
        ChecklistItem(texto: 'Ventilação natural ou exaustão apropriada'),
        ChecklistItem(texto: 'Telas em portas e aberturas'),
      ],
    ),
    Categoria(
      titulo: '2. Área de Manipulação',
      itens: [
        ChecklistItem(texto: 'Bancadas/superfícies em inox ou material lavável'),
        ChecklistItem(texto: 'Separação entre áreas suja e limpa'),
        ChecklistItem(texto: 'Equipamentos conservados e higienizados'),
        ChecklistItem(texto: 'Equipamentos calibrados (balança, termômetro)'),
        ChecklistItem(texto: 'Pia exclusiva para mãos com sabão, papel e lixeira'),
      ],
    ),
    Categoria(
      titulo: '3. Higiene e Limpeza',
      itens: [
        ChecklistItem(texto: 'Plano de limpeza e sanitização registrado'),
        ChecklistItem(texto: 'Uso de produtos saneantes regularizados'),
        ChecklistItem(texto: 'Utensílios de limpeza identificados por cor/setor'),
        ChecklistItem(texto: 'Lixeiras com tampa, limpas e com saco plástico'),
        ChecklistItem(texto: 'Frequência de limpeza documentada'),
      ],
    ),
    Categoria(
      titulo: '4. Manipuladores de Alimentos',
      itens: [
        ChecklistItem(texto: 'Uniforme limpo e completo (touca, jaleco, calçado)'),
        ChecklistItem(texto: 'Higienização das mãos frequente'),
        ChecklistItem(texto: 'Sem adornos, unhas curtas e sem esmalte'),
        ChecklistItem(texto: 'Atestados de saúde atualizados'),
        ChecklistItem(texto: 'Capacitação em boas práticas documentada'),
      ],
    ),
    Categoria(
      titulo: '5. Matérias-Primas e Insumos',
      itens: [
        ChecklistItem(texto: 'Matérias-primas em bom estado e dentro da validade'),
        ChecklistItem(texto: 'Armazenamento organizado e fora do chão'),
        ChecklistItem(texto: 'Rótulo completo com validade e identificação'),
        ChecklistItem(texto: 'Controle de recebimento com verificação completa'),
        ChecklistItem(texto: 'Rastreabilidade dos produtos (lote, fornecedor)'),
      ],
    ),
    Categoria(
      titulo: '6. Estocagem e Temperatura',
      itens: [
        ChecklistItem(texto: 'Refrigeradores limpos e com temperatura monitorada'),
        ChecklistItem(texto: 'Temperatura registrada diariamente'),
        ChecklistItem(texto: 'Alimentos etiquetados corretamente'),
        ChecklistItem(texto: 'Separação de alimentos crus e cozidos'),
        ChecklistItem(texto: 'Prateleiras afastadas do chão (mín. 15 cm)'),
      ],
    ),
    Categoria(
      titulo: '7. Preparo e Manipulação',
      itens: [
        ChecklistItem(texto: 'Fluxo de produção adequado (sem cruzamentos)'),
        ChecklistItem(texto: 'Preparo com controle de tempo e temperatura'),
        ChecklistItem(texto: 'Reaquecimento acima de 74°C'),
        ChecklistItem(texto: 'Refrigeração rápida com controle documentado'),
        ChecklistItem(texto: 'Utensílios limpos e higienizados'),
        ChecklistItem(texto: 'Fichas técnicas disponíveis e atualizadas'),
      ],
    ),
    Categoria(
      titulo: '8. Resíduos e Esgoto',
      itens: [
        ChecklistItem(texto: 'Coleta de resíduos adequada'),
        ChecklistItem(texto: 'Lixeiras sinalizadas e em número suficiente'),
        ChecklistItem(texto: 'Descarte correto de óleo'),
        ChecklistItem(texto: 'Esgoto conectado à rede pública'),
      ],
    ),
    Categoria(
      titulo: '9. Controle de Pragas',
      itens: [
        ChecklistItem(texto: 'Controle periódico com empresa especializada'),
        ChecklistItem(texto: 'Sem sinais de infestação'),
        ChecklistItem(texto: 'Telas/barreiras físicas instaladas'),
        ChecklistItem(texto: 'Armadilhas sinalizadas e fora da área de alimentos'),
      ],
    ),
    Categoria(
      titulo: '10. Documentação e Controles',
      itens: [
        ChecklistItem(texto: 'Manual de boas práticas disponível e atualizado'),
        ChecklistItem(texto: 'POPs visíveis e compreendidos'),
        ChecklistItem(texto: 'Planilhas de monitoramento atualizadas'),
        ChecklistItem(texto: 'Fichas técnicas e cardápios padronizados'),
        ChecklistItem(texto: 'Treinamentos documentados'),
        ChecklistItem(texto: 'Licenças e alvarás atualizados'),
      ],
    ),
    Categoria(
      titulo: '11. HACCP / PCC (Pontos Críticos de Controle)',
      itens: [
        ChecklistItem(texto: 'Funcionamento dos PCCs com limites críticos definidos'),
        ChecklistItem(texto: 'Documentação dos PCCs (formulários, frequências, responsáveis)'),
        ChecklistItem(texto: 'Medidas corretivas definidas em caso de desvio'),
        ChecklistItem(texto: 'Verificação e validação dos controles críticos'),
      ],
    ),
    Categoria(
      titulo: '12. Rastreabilidade e Inspeções de Qualidade',
      itens: [
        ChecklistItem(texto: 'Registro completo de lote, origem e fornecedor dos insumos'),
        ChecklistItem(texto: 'Sistema de rastreabilidade reversa (produto final para matéria-prima)'),
        ChecklistItem(texto: 'Documentação de inspeção de recebimento'),
        ChecklistItem(texto: 'Auditorias internas realizadas periodicamente'),
      ],
    ),
    Categoria(
      titulo: '13. Ensaios e Análises Laboratoriais',
      itens: [
        ChecklistItem(texto: 'Exames microbiológicos realizados conforme cronograma'),
        ChecklistItem(texto: 'Verificação de pH e parâmetros físico-químicos'),
        ChecklistItem(texto: 'Controle de qualidade sensorial (aroma, cor, textura, sabor)'),
        ChecklistItem(texto: 'Registro de resultados e ações corretivas em caso de desvios'),
      ],
    ),
    Categoria(
      titulo: '14. Gestão de Não Conformidades e Ações Corretivas',
      itens: [
        ChecklistItem(texto: 'Identificação e registro de não conformidades'),
        ChecklistItem(texto: 'Geração automática de plano de ação'),
        ChecklistItem(texto: 'Definição de responsáveis e prazos para correção'),
        ChecklistItem(texto: 'Verificação da eficácia da ação corretiva'),
      ],
    ),
    Categoria(
      titulo: '15. Indicadores e Monitoramento de Resultados',
      itens: [
        ChecklistItem(texto: 'Painel de indicadores de conformidade (KPI)'),
        ChecklistItem(texto: 'Análise de tendência de não conformidades'),
        ChecklistItem(texto: 'Relatórios gerenciais com resultados por unidade'),
        ChecklistItem(texto: 'Plano de melhoria contínua com base nos dados'),
      ],
    ),
  ];
}

/// ======================
/// PERSISTÊNCIA DO HISTÓRICO
/// ======================

Future<File> _getHistoricoFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/vistorias_history.json');
}

Future<List<VistoriaHistorico>> carregarHistorico() async {
  try {
    final file = await _getHistoricoFile();
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    if (content.trim().isEmpty) return [];
    final List<dynamic> data = jsonDecode(content);
    return data
        .map((e) => VistoriaHistorico.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> adicionarHistorico(VistoriaDados dados, String filePath) async {
  final lista = await carregarHistorico();
  lista.add(
    VistoriaHistorico(
      empresa: dados.empresa,
      cnpj: dados.cnpj,
      dataHora: dados.dataHora,
      filePath: filePath,
    ),
  );
  final file = await _getHistoricoFile();
  final jsonList = lista.map((e) => e.toJson()).toList();
  await file.writeAsString(jsonEncode(jsonList));
}

/// ======================
/// TELAS
/// ======================

/// Tela inicial: logo + bem-vindo + botões (Nova Vistoria / Histórico)
class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [backgroundColor, secondaryColor],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  SizedBox(
                    height: 120,
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.apartment, size: 64),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Bem-vindo(a) ao App de Vistorias',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Registro profissional de vistorias em boas práticas de alimentos.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.grey.shade800),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DadosEmpresaScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text(
                        'Nova Vistoria',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: primaryColor.withOpacity(0.6)),
                        foregroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const HistoricoScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.history),
                      label: const Text(
                        'Histórico de Vistorias',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tela de formulário da empresa (inclui CNPJ)
class DadosEmpresaScreen extends StatefulWidget {
  const DadosEmpresaScreen({super.key});

  @override
  State<DadosEmpresaScreen> createState() => _DadosEmpresaScreenState();
}

class _DadosEmpresaScreenState extends State<DadosEmpresaScreen> {
  final _formKey = GlobalKey<FormState>();

  final _empresaController = TextEditingController();
  final _cnpjController = TextEditingController();
  final _responsavelController = TextEditingController();
  final _contatoController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _empresaController.dispose();
    _cnpjController.dispose();
    _responsavelController.dispose();
    _contatoController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _iniciarVistoria() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final dados = VistoriaDados(
      empresa: _empresaController.text.trim(),
      cnpj: _cnpjController.text.trim(),
      responsavel: _responsavelController.text.trim(),
      contato: _contatoController.text.trim(),
      email: _emailController.text.trim(),
      dataHora: DateTime.now(),
    );

    final categorias = criarCategoriasPadrao();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoriaListScreen(
          dados: dados,
          categorias: categorias,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = 12.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dados da Vistoria'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          color: cardColor.withOpacity(0.6),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        SizedBox(
                          height: 80,
                          child: Image.asset(
                            'assets/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.apartment, size: 48),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nova Vistoria',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Dados da Empresa Vistoriada',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: primaryColor),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _empresaController,
                    decoration: const InputDecoration(
                      labelText: 'Empresa',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Informe a empresa' : null,
                  ),
                  SizedBox(height: spacing),
                  TextFormField(
                    controller: _cnpjController,
                    decoration: const InputDecoration(
                      labelText: 'CNPJ',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Informe o CNPJ' : null,
                  ),
                  SizedBox(height: spacing),
                  TextFormField(
                    controller: _responsavelController,
                    decoration: const InputDecoration(
                      labelText: 'Responsável pelo acompanhamento',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.isEmpty
                        ? 'Informe o responsável'
                        : null,
                  ),
                  SizedBox(height: spacing),
                  TextFormField(
                    controller: _contatoController,
                    decoration: const InputDecoration(
                      labelText: 'Telefone/Contato',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Informe o contato' : null,
                  ),
                  SizedBox(height: spacing),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'E-mail do responsável',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Informe o e-mail' : null,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Dados do Fiscal',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: primaryColor),
                  ),
                  const SizedBox(height: 8),
                  const Text('Caroline Carretero'),
                  const Text('Engenheira de Alimentos'),
                  const Text('Tel: (12) 99687-4743'),
                  const Text('E-mail: caconsultoriadealimento@gmail.com'),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _iniciarVistoria,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text(
                        'Iniciar Vistoria',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lista de categorias + botão de finalizar
class CategoriaListScreen extends StatefulWidget {
  final VistoriaDados dados;
  final List<Categoria> categorias;

  const CategoriaListScreen({
    super.key,
    required this.dados,
    required this.categorias,
  });

  @override
  State<CategoriaListScreen> createState() => _CategoriaListScreenState();
}

class _CategoriaListScreenState extends State<CategoriaListScreen> {
  bool _gerandoPdf = false;

  bool _tudoAvaliado() {
    for (final cat in widget.categorias) {
      for (final item in cat.itens) {
        if (item.conforme == null) return false;
      }
    }
    return true;
  }

  void _abrirCategoria(int index) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => CategoriaItensScreen(
          categoria: widget.categorias[index],
        ),
      ),
    )
        .then((_) {
      setState(() {});
    });
  }

  Future<void> _finalizarVistoria() async {
    if (!_tudoAvaliado()) {
      final continuar = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Itens não avaliados'),
          content: const Text(
            'Existem itens sem marcação de conforme/não conforme.\n\nDeseja finalizar mesmo assim?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Voltar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Finalizar'),
            ),
          ],
        ),
      );
      if (continuar != true) return;
    }

    // Coletar assinaturas
    final assinaturas = await Navigator.of(context).push<AssinaturasVistoria?>(
      MaterialPageRoute(
        builder: (_) => const AssinaturaScreen(),
      ),
    );

    if (assinaturas == null) return;

    setState(() {
      _gerandoPdf = true;
    });

    try {
      final pdfFile = await gerarPdfVistoria(
        dados: widget.dados,
        categorias: widget.categorias,
        assinaturas: assinaturas,
      );

      await adicionarHistorico(widget.dados, pdfFile.path);

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Vistoria registrada'),
          content: Text(
            'A vistoria foi registrada com sucesso.\n\nO PDF foi salvo em:\n${pdfFile.path}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await Printing.sharePdf(
                  bytes: await pdfFile.readAsBytes(),
                  filename: pdfFile.path.split(Platform.pathSeparator).last,
                );
              },
              child: const Text('Compartilhar'),
            ),
          ],
        ),
      );

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao gerar PDF: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _gerandoPdf = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categorias = widget.categorias;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorias da Vistoria'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: categorias.length,
        itemBuilder: (context, index) {
          final cat = categorias[index];

          int conformes = 0;
          int naoConformes = 0;
          int pendentes = 0;

          for (final item in cat.itens) {
            if (item.conforme == true) conformes++;
            if (item.conforme == false) naoConformes++;
            if (item.conforme == null) pendentes++;
          }

          IconData icon;
          Color iconColor;
          if (pendentes == 0 && naoConformes == 0) {
            icon = Icons.check_circle;
            iconColor = Colors.green;
          } else if (pendentes == 0 && naoConformes > 0) {
            icon = Icons.error;
            iconColor = accentDangerColor;
          } else {
            icon = Icons.hourglass_top;
            iconColor = Colors.grey;
          }

          return Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              onTap: () => _abrirCategoria(index),
              title: Text(cat.titulo),
              subtitle: Text(
                'Conformes: $conformes • Não conformes: $naoConformes • Pendentes: $pendentes',
              ),
              trailing: Icon(icon, color: iconColor),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _gerandoPdf ? null : _finalizarVistoria,
              icon: _gerandoPdf
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(
                _gerandoPdf ? 'Gerando PDF...' : 'Finalizar Vistoria',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tela de itens da categoria (1 item por vez)
class CategoriaItensScreen extends StatefulWidget {
  final Categoria categoria;

  const CategoriaItensScreen({super.key, required this.categoria});

  @override
  State<CategoriaItensScreen> createState() => _CategoriaItensScreenState();
}

class _CategoriaItensScreenState extends State<CategoriaItensScreen> {
  final _observacoesController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  int _indiceAtual = 0;

  ChecklistItem get _itemAtual => widget.categoria.itens[_indiceAtual];

  @override
  void initState() {
    super.initState();
    _carregarObservacoes();
  }

  @override
  void dispose() {
    _observacoesController.dispose();
    super.dispose();
  }

  void _carregarObservacoes() {
    _observacoesController.text = _itemAtual.observacoes ?? '';
  }

  void _salvarObservacoes() {
    _itemAtual.observacoes = _observacoesController.text.trim().isEmpty
        ? null
        : _observacoesController.text.trim();
  }

  void _voltar() {
    _salvarObservacoes();
    if (_indiceAtual > 0) {
      setState(() {
        _indiceAtual--;
        _carregarObservacoes();
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  void _irParaProximoOuVoltar() {
    if (_indiceAtual < widget.categoria.itens.length - 1) {
      setState(() {
        _indiceAtual++;
        _carregarObservacoes();
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  void _marcarConforme() {
    setState(() {
      _salvarObservacoes();
      _itemAtual.conforme = true;
      _itemAtual.fotoPath = null;
      _irParaProximoOuVoltar();
    });
  }

  Future<void> _marcarNaoConforme() async {
    _salvarObservacoes();
    final XFile? foto =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (foto == null) return;

    setState(() {
      _itemAtual.conforme = false;
      _itemAtual.fotoPath = foto.path;
      _irParaProximoOuVoltar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.categoria.itens.length;
    final atual = _indiceAtual + 1;

    String status;
    Color statusColor;
    if (_itemAtual.conforme == true) {
      status = 'Conforme';
      statusColor = Colors.green;
    } else if (_itemAtual.conforme == false) {
      status = 'Não conforme';
      statusColor = accentDangerColor;
    } else {
      status = 'Não avaliado';
      statusColor = Colors.grey;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoria.titulo),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Item $atual de $total',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _itemAtual.texto,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Situação: '),
                Text(
                  status,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_itemAtual.fotoPath != null)
              Row(
                children: const [
                  Icon(Icons.camera_alt, size: 18),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text('Foto registrada para este item.'),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _observacoesController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Observações (opcional)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _salvarObservacoes(),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _voltar,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Voltar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _marcarConforme,
                    icon: const Icon(Icons.check),
                    label: const Text('Conforme'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _marcarNaoConforme,
                    icon: const Icon(Icons.close),
                    label: const Text('Não conforme'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentDangerColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Tela de assinatura com 2 assinaturas: Responsável + Caroline
class AssinaturaScreen extends StatefulWidget {
  const AssinaturaScreen({super.key});

  @override
  State<AssinaturaScreen> createState() => _AssinaturaScreenState();
}

class _AssinaturaScreenState extends State<AssinaturaScreen> {
  final SignatureController _respController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  final SignatureController _carolineController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  bool _salvando = false;

  Future<void> _concluir() async {
    if (_respController.isEmpty || _carolineController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Por favor, colha as duas assinaturas antes de concluir.'),
        ),
      );
      return;
    }

    setState(() {
      _salvando = true;
    });

    final respBytes = await _respController.toPngBytes();
    final carolBytes = await _carolineController.toPngBytes();

    setState(() {
      _salvando = false;
    });

    if (respBytes == null || carolBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao capturar assinaturas.')),
      );
      return;
    }

    Navigator.of(context).pop(
      AssinaturasVistoria(
        responsavel: respBytes,
        caroline: carolBytes,
      ),
    );
  }

  @override
  void dispose() {
    _respController.dispose();
    _carolineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assinaturas'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Peça para o responsável e para a Caroline assinarem nos campos abaixo:',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Responsável pela empresa',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Signature(
                controller: _respController,
                backgroundColor: Colors.white,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _respController.clear(),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Limpar'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Caroline Carretero',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Signature(
                controller: _carolineController,
                backgroundColor: Colors.white,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _carolineController.clear(),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Limpar'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Spacer(),
                ElevatedButton(
                  onPressed: _salvando ? null : _concluir,
                  child: _salvando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Concluir'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Tela de histórico de PDFs
class HistoricoScreen extends StatefulWidget {
  const HistoricoScreen({super.key});

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  List<VistoriaHistorico> _historico = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final lista = await carregarHistorico();
    lista.sort((a, b) => b.dataHora.compareTo(a.dataHora));
    setState(() {
      _historico = lista;
      _carregando = false;
    });
  }

  Future<void> _abrirOuCompartilhar(VistoriaHistorico hist) async {
    final file = File(hist.filePath);
    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Arquivo não encontrado no dispositivo.')),
      );
      return;
    }

    final bytes = await file.readAsBytes();
    await Printing.sharePdf(
      bytes: bytes,
      filename: file.path.split(Platform.pathSeparator).last,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Vistorias'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _historico.isEmpty
              ? const Center(
                  child: Text('Nenhuma vistoria registrada até o momento.'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _historico.length,
                  itemBuilder: (context, index) {
                    final h = _historico[index];
                    return Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        onTap: () => _abrirOuCompartilhar(h),
                        title: Text(h.empresa),
                        subtitle: Text(
                          'CNPJ: ${h.cnpj}\n${_formatDateTime(h.dataHora)}',
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.picture_as_pdf),
                          color: primaryColor,
                          onPressed: () => _abrirOuCompartilhar(h),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

/// ======================
/// GERAÇÃO DO PDF
/// ======================

Future<File> gerarPdfVistoria({
  required VistoriaDados dados,
  required List<Categoria> categorias,
  required AssinaturasVistoria assinaturas,
}) async {
  final pdf = pw.Document();

  pw.ImageProvider? logoImage;
  try {
    final logoBytes = await rootBundle.load('assets/logo.png');
    logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
  } catch (_) {
    logoImage = null;
  }

  final dataEmissao = DateTime.now();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      header: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logoImage != null)
              pw.Container(
                width: 80,
                height: 80,
                child: pw.Image(logoImage),
              ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Caroline Carretero',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'Engenheira de Alimentos',
              style: const pw.TextStyle(fontSize: 11),
            ),
            pw.Text(
              'Tel: (12) 99687-4743  •  E-mail: caconsultoriadealimento@gmail.com',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 8),
            pw.Divider(),
            pw.SizedBox(height: 8),
          ],
        );
      },
      footer: (context) {
        return pw.Column(
          children: [
            pw.Divider(color: PdfColors.grey),
            pw.SizedBox(height: 4),
            if (logoImage != null)
              pw.Center(
                child: pw.Container(
                  width: 40,
                  height: 40,
                  child: pw.Image(logoImage),
                ),
              ),
          ],
        );
      },
      build: (context) {
        return [
          pw.Text(
            'Relatório de Vistoria de Boas Práticas',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Data da vistoria: ${_formatDateTime(dados.dataHora)}',
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(8),
              color: PdfColor.fromHex('#FFDDD2'),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Dados da Empresa Vistoriada',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text('Empresa: ${dados.empresa}'),
                pw.Text('CNPJ: ${dados.cnpj}'),
                pw.Text('Responsável: ${dados.responsavel}'),
                pw.Text('Contato: ${dados.contato}'),
                pw.Text('E-mail: ${dados.email}'),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Resultado da Vistoria',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),

          // Todas as categorias e itens
          ...categorias.expand((cat) {
            return [
              pw.SizedBox(height: 10),
              pw.Text(
                cat.titulo,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#006D77'),
                ),
              ),
              pw.SizedBox(height: 4),
              ...cat.itens.map((item) {
                String situacao;
                if (item.conforme == true) {
                  situacao = 'Conforme';
                } else if (item.conforme == false) {
                  situacao = 'Não conforme';
                } else {
                  situacao = 'Não avaliado';
                }

                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Bullet(
                      text: item.texto,
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 16, top: 2),
                      child: pw.Text(
                        situacao,
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: item.conforme == true
                              ? PdfColors.green
                              : item.conforme == false
                                  ? PdfColor.fromHex('#E29578')
                                  : PdfColors.grey,
                        ),
                      ),
                    ),
                    if (item.observacoes != null &&
                        item.observacoes!.isNotEmpty)
                      pw.Padding(
                        padding:
                            const pw.EdgeInsets.only(left: 16, top: 2),
                        child: pw.Text(
                          'Observações: ${item.observacoes}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                    if (item.conforme == false && item.fotoPath != null)
                      pw.Padding(
                        padding:
                            const pw.EdgeInsets.only(left: 16, top: 4),
                        child: _buildFotoPdf(item.fotoPath!),
                      ),
                    pw.SizedBox(height: 6),
                  ],
                );
              }),
            ];
          }).toList(),

          pw.SizedBox(height: 24),
          pw.Text(
            'Assinaturas',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                children: [
                  pw.Container(
                    width: 200,
                    height: 80,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey),
                    ),
                    child: pw.Image(
                      pw.MemoryImage(assinaturas.responsavel),
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Responsável pela empresa',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
              pw.Column(
                children: [
                  pw.Container(
                    width: 200,
                    height: 80,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey),
                    ),
                    child: pw.Image(
                      pw.MemoryImage(assinaturas.caroline),
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Caroline Carretero',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Data de emissão do relatório: ${_formatDateTime(dataEmissao)}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ];
      },
    ),
  );

  final dir = await getApplicationDocumentsDirectory();
  final empresaSafe = _sanitizeFileName(dados.empresa);
  final dataSafe =
      '${dados.dataHora.year}${dados.dataHora.month.toString().padLeft(2, '0')}${dados.dataHora.day.toString().padLeft(2, '0')}_${dados.dataHora.hour.toString().padLeft(2, '0')}${dados.dataHora.minute.toString().padLeft(2, '0')}';
  final fileName = 'vistoria_${empresaSafe}_$dataSafe.pdf';
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(await pdf.save());
  return file;
}

pw.Widget _buildFotoPdf(String path) {
  try {
    final file = File(path);
    final bytes = file.readAsBytesSync();
    final image = pw.MemoryImage(bytes);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Foto da não conformidade:',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          width: 200,
          height: 150,
          child: pw.Image(image, fit: pw.BoxFit.cover),
        ),
      ],
    );
  } catch (_) {
    return pw.Text(
      'Erro ao carregar foto.',
      style: const pw.TextStyle(fontSize: 10),
    );
  }
}
